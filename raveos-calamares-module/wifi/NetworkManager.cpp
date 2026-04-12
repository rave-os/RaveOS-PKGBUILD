#include "NetworkManager.h"

#include <QDBusInterface>
#include <QDBusReply>
#include <QDBusObjectPath>
#include <QDBusArgument>
#include <QDBusMetaType>
#include <QDBusMessage>
#include <QVariantMap>
#include <QTimer>
#include <QDebug>
#include <QFile>
#include <QTextStream>
#include <QDateTime>

// NetworkManager expects a{sa{sv}} type for connection settings
typedef QMap<QString, QVariantMap> NMConnectionSettings;

// Log file path
static const QString LOG_FILE = "/tmp/calamares-wifi.log";

static void wifiLog(const QString& message)
{
    QString timestamp = QDateTime::currentDateTime().toString("yyyy-MM-dd hh:mm:ss.zzz");
    QString logLine = QString("[%1] %2\n").arg(timestamp, message);

    // Write to file
    QFile file(LOG_FILE);
    if (file.open(QIODevice::Append | QIODevice::Text))
    {
        QTextStream stream(&file);
        stream << logLine;
        file.close();
    }

    // Also print to debug output
    qDebug().noquote() << "[WiFi Module]" << message;
}

NetworkManager::NetworkManager(QObject* parent)
    : QObject(parent)
{
    // Register the custom DBus type
    qDBusRegisterMetaType<NMConnectionSettings>();

    // Clear log file on start
    QFile file(LOG_FILE);
    if (file.open(QIODevice::WriteOnly | QIODevice::Text))
    {
        QTextStream stream(&file);
        stream << "=== Calamares WiFi Module Log ===\n";
        file.close();
    }

    wifiLog("NetworkManager initialized");
    scan();
    updateConnectionState();

    // Periodic connection state update
    QTimer* timer = new QTimer(this);
    connect(timer, &QTimer::timeout, this, &NetworkManager::updateConnectionState);
    timer->start(3000);
}

QStringList NetworkManager::networks() const
{
    return m_networks;
}

bool NetworkManager::isConnected() const
{
    return m_connected;
}

void NetworkManager::updateConnectionState()
{
    QDBusInterface nm(
        "org.freedesktop.NetworkManager",
        "/org/freedesktop/NetworkManager",
        "org.freedesktop.NetworkManager",
        QDBusConnection::systemBus()
    );

    if (!nm.isValid())
    {
        return;
    }

    bool newState = false;

    // Method 1: Check PrimaryConnection
    QDBusObjectPath primary =
        nm.property("PrimaryConnection").value<QDBusObjectPath>();

    if (primary.path() != "/" && !primary.path().isEmpty())
    {
        newState = true;
    }

    // Method 2: Check if any WiFi device is in activated state (100)
    if (!newState)
    {
        QDBusReply<QList<QDBusObjectPath>> devices = nm.call("GetDevices");
        if (devices.isValid())
        {
            for (const auto& dev : devices.value())
            {
                QDBusInterface devProps(
                    "org.freedesktop.NetworkManager",
                    dev.path(),
                    "org.freedesktop.DBus.Properties",
                    QDBusConnection::systemBus()
                );

                QDBusReply<QVariant> typeReply = devProps.call(
                    "Get",
                    "org.freedesktop.NetworkManager.Device",
                    "DeviceType"
                );

                // DeviceType 2 = WiFi
                if (typeReply.isValid() && typeReply.value().toUInt() == 2)
                {
                    QDBusReply<QVariant> stateReply = devProps.call(
                        "Get",
                        "org.freedesktop.NetworkManager.Device",
                        "State"
                    );

                    // State 100 = NM_DEVICE_STATE_ACTIVATED
                    if (stateReply.isValid())
                    {
                        uint state = stateReply.value().toUInt();
                        wifiLog(QString("WiFi device state: %1").arg(state));
                        if (state == 100)
                        {
                            newState = true;
                            break;
                        }
                    }
                }
            }
        }
    }

    if (newState != m_connected)
    {
        m_connected = newState;
        wifiLog(QString("Connection state changed to: %1").arg(newState ? "connected" : "disconnected"));
        emit connectionChanged();
    }
}

void NetworkManager::scan()
{
    m_networks.clear();
    wifiLog("Starting scan...");

    QDBusInterface nm(
        "org.freedesktop.NetworkManager",
        "/org/freedesktop/NetworkManager",
        "org.freedesktop.NetworkManager",
        QDBusConnection::systemBus()
    );

    if (!nm.isValid())
    {
        wifiLog("NetworkManager DBus interface not valid!");
        emit networksChanged();
        return;
    }

    QDBusReply<QList<QDBusObjectPath>> devices = nm.call("GetDevices");

    if (!devices.isValid())
    {
        wifiLog(QString("GetDevices failed: %1").arg(devices.error().message()));
        emit networksChanged();
        return;
    }

    wifiLog(QString("Found %1 devices").arg(devices.value().size()));

    bool foundWireless = false;
    for (const auto& dev : devices.value())
    {
        // Check DeviceType first - type 2 = WiFi
        QDBusInterface devProps(
            "org.freedesktop.NetworkManager",
            dev.path(),
            "org.freedesktop.DBus.Properties",
            QDBusConnection::systemBus()
        );

        QDBusReply<QVariant> typeReply = devProps.call(
            "Get",
            "org.freedesktop.NetworkManager.Device",
            "DeviceType"
        );

        uint deviceType = typeReply.isValid() ? typeReply.value().toUInt() : 0;
        wifiLog(QString("Device %1 type: %2").arg(dev.path()).arg(deviceType));

        if (deviceType != 2)  // Not WiFi
            continue;

        foundWireless = true;
        wifiLog(QString("Found wireless device: %1").arg(dev.path()));

        // Now use the Wireless interface for scanning
        QDBusInterface wirelessIf(
            "org.freedesktop.NetworkManager",
            dev.path(),
            "org.freedesktop.NetworkManager.Device.Wireless",
            QDBusConnection::systemBus()
        );

        // Request a new scan - this is async
        QDBusMessage reply = wirelessIf.call("RequestScan", QVariantMap());
        if (reply.type() == QDBusMessage::ErrorMessage) {
            wifiLog(QString("Scan request failed: %1").arg(reply.errorMessage()));
        } else {
            wifiLog("Scan request sent successfully");
        }
    }

    if (!foundWireless) {
        wifiLog("No wireless devices found!");
    }

    // Wait for scan to complete, then fetch results
    QTimer::singleShot(2000, this, &NetworkManager::fetchAccessPoints);
}

void NetworkManager::fetchAccessPoints()
{
    m_networks.clear();
    wifiLog("Fetching access points...");

    QDBusInterface nm(
        "org.freedesktop.NetworkManager",
        "/org/freedesktop/NetworkManager",
        "org.freedesktop.NetworkManager",
        QDBusConnection::systemBus()
    );

    if (!nm.isValid())
    {
        wifiLog("NM interface not valid in fetchAccessPoints");
        emit networksChanged();
        return;
    }

    QDBusReply<QList<QDBusObjectPath>> devices = nm.call("GetDevices");

    if (!devices.isValid())
    {
        wifiLog("GetDevices failed in fetchAccessPoints");
        emit networksChanged();
        return;
    }

    for (const auto& dev : devices.value())
    {
        // Check DeviceType first - type 2 = WiFi
        QDBusInterface devProps(
            "org.freedesktop.NetworkManager",
            dev.path(),
            "org.freedesktop.DBus.Properties",
            QDBusConnection::systemBus()
        );

        QDBusReply<QVariant> typeReply = devProps.call(
            "Get",
            "org.freedesktop.NetworkManager.Device",
            "DeviceType"
        );

        if (!typeReply.isValid() || typeReply.value().toUInt() != 2)
            continue;  // Not WiFi

        QDBusInterface wirelessIf(
            "org.freedesktop.NetworkManager",
            dev.path(),
            "org.freedesktop.NetworkManager.Device.Wireless",
            QDBusConnection::systemBus()
        );

        QDBusReply<QList<QDBusObjectPath>> aps =
            wirelessIf.call("GetAccessPoints");

        if (!aps.isValid()) {
            wifiLog(QString("GetAccessPoints failed: %1").arg(aps.error().message()));
            continue;
        }

        wifiLog(QString("Found %1 access points on device %2").arg(aps.value().size()).arg(dev.path()));

        for (const auto& ap : aps.value())
        {
            QDBusInterface apIf(
                "org.freedesktop.NetworkManager",
                ap.path(),
                "org.freedesktop.NetworkManager.AccessPoint",
                QDBusConnection::systemBus()
            );

            QByteArray ssidRaw = apIf.property("Ssid").toByteArray();
            QString ssid = QString::fromUtf8(ssidRaw);

            // Get frequency to show 2.4G vs 5G
            uint frequency = apIf.property("Frequency").toUInt();
            QString band = (frequency > 4000) ? "5GHz" : "2.4GHz";

            wifiLog(QString("Found SSID: %1 (%2, %3 MHz)").arg(ssid, band).arg(frequency));

            if (!ssid.isEmpty() && !m_networks.contains(ssid))
                m_networks << ssid;
        }
    }

    // Sort networks alphabetically
    m_networks.sort(Qt::CaseInsensitive);

    wifiLog(QString("Total networks found: %1").arg(m_networks.size()));
    emit networksChanged();
}

void NetworkManager::connectTo(const QString& ssid, const QString& password)
{
    wifiLog(QString("Connecting to: %1").arg(ssid));

    QDBusInterface nm(
        "org.freedesktop.NetworkManager",
        "/org/freedesktop/NetworkManager",
        "org.freedesktop.NetworkManager",
        QDBusConnection::systemBus()
    );

    if (!nm.isValid())
    {
        wifiLog("NM interface not valid for connection");
        return;
    }

    // Find the wireless device
    QDBusReply<QList<QDBusObjectPath>> devices = nm.call("GetDevices");
    if (!devices.isValid())
    {
        wifiLog(QString("GetDevices failed: %1").arg(devices.error().message()));
        return;
    }

    QDBusObjectPath wirelessDevice("/");
    QDBusObjectPath accessPoint("/");
    uint apFlags = 0;
    uint apWpaFlags = 0;
    uint apRsnFlags = 0;

    for (const auto& dev : devices.value())
    {
        QDBusInterface devProps(
            "org.freedesktop.NetworkManager",
            dev.path(),
            "org.freedesktop.DBus.Properties",
            QDBusConnection::systemBus()
        );

        QDBusReply<QVariant> typeReply = devProps.call(
            "Get",
            "org.freedesktop.NetworkManager.Device",
            "DeviceType"
        );

        // DeviceType 2 = WiFi
        if (typeReply.isValid() && typeReply.value().toUInt() == 2)
        {
            wirelessDevice = dev;
            wifiLog(QString("Using wireless device: %1").arg(dev.path()));

            // Find the access point for this SSID
            QDBusInterface wirelessIf(
                "org.freedesktop.NetworkManager",
                dev.path(),
                "org.freedesktop.NetworkManager.Device.Wireless",
                QDBusConnection::systemBus()
            );

            QDBusReply<QList<QDBusObjectPath>> aps = wirelessIf.call("GetAccessPoints");
            if (aps.isValid())
            {
                for (const auto& ap : aps.value())
                {
                    QDBusInterface apIf(
                        "org.freedesktop.NetworkManager",
                        ap.path(),
                        "org.freedesktop.NetworkManager.AccessPoint",
                        QDBusConnection::systemBus()
                    );

                    QByteArray apSsid = apIf.property("Ssid").toByteArray();
                    if (QString::fromUtf8(apSsid) == ssid)
                    {
                        accessPoint = ap;
                        // Get security flags from AP
                        apFlags = apIf.property("Flags").toUInt();
                        apWpaFlags = apIf.property("WpaFlags").toUInt();
                        apRsnFlags = apIf.property("RsnFlags").toUInt();
                        wifiLog(QString("Found access point: %1").arg(ap.path()));
                        wifiLog(QString("AP Flags: 0x%1, WpaFlags: 0x%2, RsnFlags: 0x%3")
                            .arg(apFlags, 0, 16).arg(apWpaFlags, 0, 16).arg(apRsnFlags, 0, 16));
                        break;
                    }
                }
            }
            break;
        }
    }

    if (wirelessDevice.path() == "/" || wirelessDevice.path().isEmpty())
    {
        wifiLog("No wireless device found!");
        return;
    }

    // Determine security type from AP flags
    // NM_802_11_AP_SEC flags:
    // 0x100 = KEY_MGMT_PSK (WPA/WPA2 Personal)
    // 0x200 = KEY_MGMT_802_1X (WPA/WPA2 Enterprise)
    // 0x400 = KEY_MGMT_SAE (WPA3)
    // 0x800 = KEY_MGMT_OWE (Enhanced Open)

    bool apSupportsPsk = ((apWpaFlags & 0x100) != 0) || ((apRsnFlags & 0x100) != 0);
    bool apSupportsSae = (apRsnFlags & 0x400) != 0;  // WPA3
    bool apSupportsEnterprise = ((apWpaFlags & 0x200) != 0) || ((apRsnFlags & 0x200) != 0);
    bool apIsOpen = (apFlags == 0) && (apWpaFlags == 0) && (apRsnFlags == 0);

    // Privacy flag (0x1) means network is secured (WEP or better)
    bool apHasPrivacy = (apFlags & 0x1) != 0;

    wifiLog(QString("Security detection: PSK=%1, SAE=%2, Enterprise=%3, Open=%4, Privacy=%5")
        .arg(apSupportsPsk).arg(apSupportsSae).arg(apSupportsEnterprise).arg(apIsOpen).arg(apHasPrivacy));

    // Build connection settings using proper NM types
    QVariantMap connection;
    connection["type"] = QString("802-11-wireless");
    connection["id"] = ssid;
    connection["autoconnect"] = true;

    QVariantMap wifi;
    wifi["ssid"] = ssid.toUtf8();
    wifi["mode"] = QString("infrastructure");

    // For hidden networks, we need to set hidden flag
    bool isHiddenNetwork = (accessPoint.path() == "/" || accessPoint.path().isEmpty());
    if (isHiddenNetwork)
    {
        wifi["hidden"] = true;
        wifiLog("Treating as hidden network");
    }

    // Build settings map
    NMConnectionSettings settings;
    settings["connection"] = connection;

    QVariantMap ipv4;
    ipv4["method"] = QString("auto");
    settings["ipv4"] = ipv4;

    QVariantMap ipv6;
    ipv6["method"] = QString("auto");
    settings["ipv6"] = ipv6;

    // Determine and apply security settings based on AP capabilities
    if (!password.isEmpty() && (apSupportsPsk || apSupportsSae || isHiddenNetwork))
    {
        // Password provided and AP supports PSK or SAE (or it's hidden, assume PSK)
        QVariantMap wifiSecurity;

        if (apSupportsSae && !apSupportsPsk)
        {
            // WPA3-only network
            wifiLog("Using WPA3-SAE security");
            wifiSecurity["key-mgmt"] = QString("sae");
            wifiSecurity["psk"] = password;
            // PMF (Protected Management Frames) is MANDATORY for WPA3-SAE
            // 0 = default, 1 = disable, 2 = optional, 3 = required
            wifiSecurity["pmf"] = 3;
        }
        else if (apSupportsPsk)
        {
            // Check if this is WPA2/WPA3 transition mode (supports both PSK and SAE)
            if (apSupportsSae)
            {
                // Transition mode: prefer WPA3-SAE if available
                wifiLog("Using WPA3-SAE (transition mode - both PSK and SAE available)");
                wifiSecurity["key-mgmt"] = QString("sae");
                wifiSecurity["psk"] = password;
                wifiSecurity["pmf"] = 3;  // Required for SAE
            }
            else
            {
                // Pure WPA/WPA2-PSK network (most common)
                wifiLog("Using WPA-PSK security");
                wifiSecurity["key-mgmt"] = QString("wpa-psk");
                wifiSecurity["psk"] = password;
            }
        }
        else if (isHiddenNetwork)
        {
            // Hidden network with password - assume WPA-PSK
            wifiLog("Hidden network with password, assuming WPA-PSK");
            wifiSecurity["key-mgmt"] = QString("wpa-psk");
            wifiSecurity["psk"] = password;
        }

        wifi["security"] = QString("802-11-wireless-security");
        settings["802-11-wireless"] = wifi;
        settings["802-11-wireless-security"] = wifiSecurity;
    }
    else if (apSupportsEnterprise)
    {
        // Enterprise networks require more complex configuration
        wifiLog("WARNING: Enterprise (802.1X) networks are not supported by this simple connector");
        return;
    }
    else if (apIsOpen || (!apHasPrivacy && !apSupportsPsk && !apSupportsSae))
    {
        // Open network - no security settings needed
        wifiLog("Connecting to open network (no security)");
        settings["802-11-wireless"] = wifi;
    }
    else if (!password.isEmpty() && !apSupportsPsk && !apSupportsSae)
    {
        // Password provided but AP doesn't support PSK/SAE
        // This is the error case from the log!
        wifiLog("WARNING: Password provided but AP does not support PSK/SAE authentication!");
        wifiLog("Attempting to connect as open network...");
        settings["802-11-wireless"] = wifi;
    }
    else
    {
        // Fallback - no password, assume open
        wifiLog("No password provided, treating as open network");
        settings["802-11-wireless"] = wifi;
    }

    wifiLog("Calling AddAndActivateConnection...");

    // Use AddAndActivateConnection with proper DBus argument
    QDBusMessage msg = QDBusMessage::createMethodCall(
        "org.freedesktop.NetworkManager",
        "/org/freedesktop/NetworkManager",
        "org.freedesktop.NetworkManager",
        "AddAndActivateConnection"
    );

    // Serialize settings properly for DBus
    QDBusArgument settingsArg;
    settingsArg.beginMap(QMetaType::fromType<QString>(), QMetaType::fromType<QVariantMap>());
    for (auto it = settings.constBegin(); it != settings.constEnd(); ++it)
    {
        settingsArg.beginMapEntry();
        settingsArg << it.key() << it.value();
        settingsArg.endMapEntry();
    }
    settingsArg.endMap();

    msg << QVariant::fromValue(settingsArg);
    msg << QVariant::fromValue(wirelessDevice);
    msg << QVariant::fromValue(accessPoint);

    QDBusMessage reply = QDBusConnection::systemBus().call(msg);

    if (reply.type() == QDBusMessage::ErrorMessage)
    {
        wifiLog(QString("Connection failed: %1 - %2").arg(reply.errorName(), reply.errorMessage()));
        emit connectionFailed(reply.errorMessage());
    }
    else
    {
        wifiLog("Connection initiated successfully");
        // Save credentials for later use (to be saved to installed system)
        m_lastConnectedSsid = ssid;
        m_lastConnectedPassword = password;
        wifiLog(QString("Stored credentials - SSID: '%1', Password length: %2").arg(m_lastConnectedSsid).arg(m_lastConnectedPassword.length()));

        // Determine and save security type
        if (apSupportsSae && !apSupportsPsk)
        {
            m_lastSecurityType = "sae";
        }
        else if (apSupportsPsk && apSupportsSae)
        {
            m_lastSecurityType = "sae";  // Transition mode, we used SAE
        }
        else if (apSupportsPsk)
        {
            m_lastSecurityType = "wpa-psk";
        }
        else
        {
            m_lastSecurityType = "";  // Open network
        }
        wifiLog(QString("Stored security type: '%1'").arg(m_lastSecurityType));

        // Note: WiFi persistence to installed system is disabled
        // Connection only works during installation

        // Check connection state multiple times (WPA3-SAE can be slow)
        m_connectionCheckCount = 0;
        startConnectionCheck();
    }
}

void NetworkManager::startConnectionCheck()
{
    m_connectionCheckCount++;
    wifiLog(QString("Connection check attempt %1/10").arg(m_connectionCheckCount));

    updateConnectionState();

    if (m_connected)
    {
        wifiLog("Connection confirmed!");
        return;
    }

    // Retry up to 10 times (every 1 second = 10 seconds total)
    if (m_connectionCheckCount < 10)
    {
        QTimer::singleShot(1000, this, &NetworkManager::startConnectionCheck);
    }
    else
    {
        wifiLog("Connection check timeout - connection may have failed");
        emit connectionFailed("Connection timeout");
    }
}
