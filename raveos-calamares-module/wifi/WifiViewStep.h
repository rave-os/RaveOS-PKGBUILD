#pragma once

#include <QObject>
#include <QWidget>
#include <QTimer>

#include <utils/PluginFactory.h>
#include <viewpages/ViewStep.h>
#include <Job.h>

#include "NetworkManager.h"

class QQuickWidget;

class PLUGINDLLEXPORT WifiViewStep : public Calamares::ViewStep
{
    Q_OBJECT

public:
    explicit WifiViewStep(QObject* parent = nullptr);
    ~WifiViewStep() override;

    QString prettyName() const override;
    QWidget* widget() override;

    bool isNextEnabled() const override;
    bool isBackEnabled() const override;
    bool isAtBeginning() const override;
    bool isAtEnd() const override;

    Calamares::JobList jobs() const override;

    void onActivate() override;
    void onLeave() override;

    void setConfigurationMap(const QVariantMap& configurationMap) override;

private slots:
    void skipToNext();
    void checkNetworkStatus();
    void onNetworkStateChanged();

private:
    bool hasWiredConnection() const;
    bool hasActiveNetwork() const;
    QString getLocale() const;
    void updateLocale();

    QWidget* m_widget = nullptr;
    QQuickWidget* m_quickWidget = nullptr;
    NetworkManager* m_networkManager = nullptr;
    QTimer* m_networkCheckTimer = nullptr;
    mutable QString m_locale;

    bool m_firstActivation = true;
    mutable bool m_lastNetworkState = false;
};

CALAMARES_PLUGIN_FACTORY_DECLARATION(WifiViewStepFactory)
