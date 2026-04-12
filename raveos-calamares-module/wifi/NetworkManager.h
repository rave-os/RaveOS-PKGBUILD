#pragma once

#include <QObject>
#include <QString>
#include <QStringList>

class NetworkManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QStringList networks READ networks NOTIFY networksChanged)
    Q_PROPERTY(bool connected READ isConnected NOTIFY connectionChanged)

public:
    explicit NetworkManager(QObject* parent = nullptr);

    QStringList networks() const;
    bool isConnected() const;

    // Get the last connected network credentials (for saving to installed system)
    QString lastConnectedSsid() const { return m_lastConnectedSsid; }
    QString lastConnectedPassword() const { return m_lastConnectedPassword; }
    QString lastSecurityType() const { return m_lastSecurityType; }  // "wpa-psk" or "sae"

public slots:
    void scan();
    void connectTo(const QString& ssid, const QString& password);

signals:
    void networksChanged();
    void connectionChanged();
    void connectionFailed(const QString& error);

private slots:
    void startConnectionCheck();

private:
    void updateConnectionState();
    void fetchAccessPoints();

    QStringList m_networks;
    bool m_connected = false;

    // Store credentials for saving to installed system
    QString m_lastConnectedSsid;
    QString m_lastConnectedPassword;
    QString m_lastSecurityType;  // "wpa-psk", "sae", or "" (open)
    int m_connectionCheckCount = 0;
};
