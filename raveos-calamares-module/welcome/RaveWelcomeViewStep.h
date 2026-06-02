#pragma once

#include <QObject>
#include <QWidget>
#include <QStringList>

#include <utils/PluginFactory.h>
#include <viewpages/ViewStep.h>
#include <Job.h>

class QComboBox;
class QLabel;

class PLUGINDLLEXPORT RaveWelcomeViewStep : public Calamares::ViewStep
{
    Q_OBJECT

public:
    explicit RaveWelcomeViewStep(QObject* parent = nullptr);
    ~RaveWelcomeViewStep() override;

    QString prettyName() const override;
    QWidget* widget() override;

    bool isNextEnabled() const override;
    bool isBackEnabled() const override;
    bool isAtBeginning() const override;
    bool isAtEnd() const override;

    Calamares::JobList jobs() const override;

    void setConfigurationMap(const QVariantMap& configurationMap) override;

private slots:
    void onLanguageChanged(int index);

private:
    void buildWidget();
    QString brandingTranslationsPrefix() const;

    QWidget*   m_widget   = nullptr;
    QLabel*    m_bgLabel  = nullptr;
    QComboBox* m_langCombo = nullptr;

    QStringList m_localeIds;
    int         m_currentLocaleIndex = 0;
};

CALAMARES_PLUGIN_FACTORY_DECLARATION(RaveWelcomeViewStepFactory)
