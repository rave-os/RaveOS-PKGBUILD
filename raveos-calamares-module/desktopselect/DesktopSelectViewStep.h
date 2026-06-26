#pragma once
#include <viewpages/ViewStep.h>
#include <utils/PluginFactory.h>
#include <Job.h>
#include <QObject>
#include <QWidget>
#include <QStringList>
#include "DesktopBackend.h"

class QQuickWidget;

class PLUGINDLLEXPORT DesktopSelectViewStep : public Calamares::ViewStep
{
    Q_OBJECT

public:
    explicit DesktopSelectViewStep(QObject* parent = nullptr);
    ~DesktopSelectViewStep() override;

    QString prettyName() const override;
    QWidget* widget() override;

    bool isNextEnabled() const override;
    bool isBackEnabled() const override;
    bool isAtBeginning() const override;
    bool isAtEnd() const override;

    Calamares::JobList jobs() const override;

    void setConfigurationMap(const QVariantMap& config) override;
    void onLeave() override;

private:
    void buildWidget();

    QWidget* m_widget = nullptr;
    QQuickWidget* m_quickWidget = nullptr;
    DesktopBackend* m_backend = nullptr;
    QStringList m_mandatoryPackages;
};

CALAMARES_PLUGIN_FACTORY_DECLARATION(DesktopSelectViewStepFactory)
