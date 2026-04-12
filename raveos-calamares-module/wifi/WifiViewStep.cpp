#include "WifiViewStep.h"

#include <QVBoxLayout>
#include <QQuickWidget>
#include <QQmlContext>
#include <QQmlEngine>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDBusObjectPath>
#include <QDir>
#include <QLocale>
#include <QTimer>
#include <QNetworkInterface>
#include <QQuickItem>

#include <GlobalStorage.h>
#include <JobQueue.h>
#include <ViewManager.h>

CALAMARES_PLUGIN_FACTORY_DEFINITION(WifiViewStepFactory, registerPlugin<WifiViewStep>();)

WifiViewStep::WifiViewStep(QObject* parent)
    : Calamares::ViewStep(parent)
    , m_networkManager(new NetworkManager(this))
    , m_networkCheckTimer(new QTimer(this))
    , m_firstActivation(true)
    , m_lastNetworkState(false)
{
    m_locale = getLocale();

    connect(m_networkManager, &NetworkManager::connectionChanged,
            this, &WifiViewStep::onNetworkStateChanged);

    connect(m_networkCheckTimer, &QTimer::timeout,
            this, &WifiViewStep::checkNetworkStatus);
}

WifiViewStep::~WifiViewStep()
{
    if (m_networkCheckTimer)
    {
        m_networkCheckTimer->stop();
    }

    if (m_widget && m_widget->parent() == nullptr)
    {
        delete m_widget;
    }
}

QString WifiViewStep::prettyName() const
{
    m_locale = getLocale();

    if (m_locale.startsWith("hu"))
    {
        return QStringLiteral("Wi-Fi");
    }
    return QStringLiteral("Wi-Fi");
}

QWidget* WifiViewStep::widget()
{
    if (!m_widget)
    {
        m_widget = new QWidget();
        QVBoxLayout* layout = new QVBoxLayout(m_widget);

        m_quickWidget = new QQuickWidget();
        m_quickWidget->setResizeMode(QQuickWidget::SizeRootObjectToView);

        QString modulePath = QStringLiteral("/usr/lib/calamares/modules/wifi/ui");
        if (!QDir(modulePath).exists())
        {
            modulePath = QDir::currentPath() + QStringLiteral("/wifi/ui");
        }
        m_quickWidget->engine()->addImportPath(modulePath);

        m_quickWidget->rootContext()->setContextProperty("nm", m_networkManager);

        m_locale = getLocale();
        m_quickWidget->rootContext()->setContextProperty("systemLocale", m_locale);

        QString qmlPath = QStringLiteral("/usr/lib/calamares/modules/wifi/ui/wifi.qml");

        if (!QFile::exists(qmlPath))
        {
            qmlPath = QDir::currentPath() + QStringLiteral("/wifi/ui/wifi.qml");
        }

        m_quickWidget->setSource(QUrl::fromLocalFile(qmlPath));

        layout->addWidget(m_quickWidget);
        layout->setContentsMargins(0, 0, 0, 0);
    }

    return m_widget;
}

bool WifiViewStep::isNextEnabled() const
{
    bool hasNetwork = hasActiveNetwork();
    m_lastNetworkState = hasNetwork;
    return hasNetwork;
}

bool WifiViewStep::isBackEnabled() const
{
    return true;
}

bool WifiViewStep::isAtBeginning() const
{
    return true;
}

bool WifiViewStep::isAtEnd() const
{
    return true;
}

Calamares::JobList WifiViewStep::jobs() const
{
    // WiFi persistence disabled - connection only works during installation
    // The WiFi module only provides network connectivity for the installer
    return Calamares::JobList();
}

void WifiViewStep::onActivate()
{
    // Force update locale from GlobalStorage
    QString newLocale = getLocale();
    m_locale = newLocale;

    // Update QML context property
    if (m_quickWidget)
    {
        m_quickWidget->rootContext()->setContextProperty("systemLocale", m_locale);

        // Force QML to re-read the locale by calling a method on root object
        QQuickItem* root = m_quickWidget->rootObject();
        if (root)
        {
            QMetaObject::invokeMethod(root, "updateLanguage", Qt::DirectConnection);
        }
    }

    // Start network check timer
    m_networkCheckTimer->start(2000);

    // Check initial network state
    m_lastNetworkState = hasActiveNetwork();

    // Auto-skip ONLY on first activation AND if there's network
    if (m_firstActivation && m_lastNetworkState)
    {
        m_firstActivation = false;
        QTimer::singleShot(50, this, &WifiViewStep::skipToNext);
        return;
    }

    // Mark as no longer first activation
    m_firstActivation = false;

    // Normal activation - show WiFi setup
    m_networkManager->scan();

    // Emit initial state
    emit nextStatusChanged(m_lastNetworkState);
}

void WifiViewStep::skipToNext()
{
    Calamares::ViewManager* vm = Calamares::ViewManager::instance();
    if (vm)
    {
        vm->next();
    }
}

void WifiViewStep::onLeave()
{
    m_networkCheckTimer->stop();
}

void WifiViewStep::checkNetworkStatus()
{
    bool currentState = hasActiveNetwork();

    if (currentState != m_lastNetworkState)
    {
        m_lastNetworkState = currentState;
        emit nextStatusChanged(currentState);
    }
}

void WifiViewStep::onNetworkStateChanged()
{
    checkNetworkStatus();
}

void WifiViewStep::setConfigurationMap(const QVariantMap& configurationMap)
{
    Q_UNUSED(configurationMap)
}

void WifiViewStep::updateLocale()
{
    QString newLocale = getLocale();
    if (newLocale != m_locale)
    {
        m_locale = newLocale;
        if (m_quickWidget)
        {
            m_quickWidget->rootContext()->setContextProperty("systemLocale", m_locale);
        }
    }
}

QString WifiViewStep::getLocale() const
{
    if (Calamares::JobQueue::instance())
    {
        Calamares::GlobalStorage* gs = Calamares::JobQueue::instance()->globalStorage();

        if (gs)
        {
            // Check all possible locale keys that Calamares might use

            // Key 1: "locale" (direct string)
            if (gs->contains("locale"))
            {
                QString loc = gs->value("locale").toString();
                if (!loc.isEmpty())
                    return loc;
            }

            // Key 2: "lang" (some modules use this)
            if (gs->contains("lang"))
            {
                QString loc = gs->value("lang").toString();
                if (!loc.isEmpty())
                    return loc;
            }

            // Key 3: "language"
            if (gs->contains("language"))
            {
                QString loc = gs->value("language").toString();
                if (!loc.isEmpty())
                    return loc;
            }

            // Key 4: "localeConf" map with LANG key
            if (gs->contains("localeConf"))
            {
                QVariantMap localeConf = gs->value("localeConf").toMap();
                if (localeConf.contains("LANG"))
                {
                    QString loc = localeConf.value("LANG").toString();
                    if (!loc.isEmpty())
                        return loc;
                }
            }

            // Key 5: Check for region-based locale
            if (gs->contains("locationRegion"))
            {
                QString region = gs->value("locationRegion").toString();
                if (region.contains("Budapest") || region.contains("Hungary"))
                {
                    return QStringLiteral("hu_HU");
                }
            }

            // Key 6: "localeIndex" - welcome module sometimes stores index
            // We'd need to map this to actual locale
        }
    }

    // Fallback to system locale
    return QLocale::system().name();
}

bool WifiViewStep::hasActiveNetwork() const
{
    const QList<QNetworkInterface> interfaces = QNetworkInterface::allInterfaces();

    for (const QNetworkInterface& iface : interfaces)
    {
        if (iface.flags().testFlag(QNetworkInterface::IsLoopBack))
            continue;

        if (!iface.flags().testFlag(QNetworkInterface::IsUp))
            continue;

        if (!iface.flags().testFlag(QNetworkInterface::IsRunning))
            continue;

        const QList<QNetworkAddressEntry> entries = iface.addressEntries();
        for (const QNetworkAddressEntry& entry : entries)
        {
            QHostAddress ip = entry.ip();

            if (ip.protocol() != QAbstractSocket::IPv4Protocol)
                continue;

            if (ip.isLoopback())
                continue;

            QString ipStr = ip.toString();

            if (ipStr.startsWith("169.254."))
                continue;

            return true;
        }
    }

    return hasWiredConnection() || m_networkManager->isConnected();
}

bool WifiViewStep::hasWiredConnection() const
{
    QDBusInterface nm(
        "org.freedesktop.NetworkManager",
        "/org/freedesktop/NetworkManager",
        "org.freedesktop.NetworkManager",
        QDBusConnection::systemBus()
    );

    if (!nm.isValid())
    {
        return false;
    }

    QDBusReply<QList<QDBusObjectPath>> devices = nm.call("GetDevices");
    if (!devices.isValid())
    {
        return false;
    }

    for (const auto& devPath : devices.value())
    {
        QDBusInterface devIf(
            "org.freedesktop.NetworkManager",
            devPath.path(),
            "org.freedesktop.DBus.Properties",
            QDBusConnection::systemBus()
        );

        QDBusReply<QVariant> typeReply = devIf.call(
            "Get",
            "org.freedesktop.NetworkManager.Device",
            "DeviceType"
        );

        if (!typeReply.isValid())
        {
            continue;
        }

        uint deviceType = typeReply.value().toUInt();

        if (deviceType == 1)
        {
            QDBusReply<QVariant> stateReply = devIf.call(
                "Get",
                "org.freedesktop.NetworkManager.Device",
                "State"
            );

            if (stateReply.isValid() && stateReply.value().toUInt() == 100)
            {
                return true;
            }
        }
    }

    return false;
}
