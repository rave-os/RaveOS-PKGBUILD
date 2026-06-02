#include "RaveWelcomeViewStep.h"

#include <QComboBox>
#include <QFrame>
#include <QHBoxLayout>
#include <QLabel>
#include <QLocale>
#include <QPainter>
#include <QPixmap>
#include <QResizeEvent>
#include <QVBoxLayout>

#include <Branding.h>
#include <GlobalStorage.h>
#include <JobQueue.h>
#include <locale/Translation.h>
#include <locale/TranslationsModel.h>
#include <utils/Retranslator.h>

CALAMARES_PLUGIN_FACTORY_DEFINITION(RaveWelcomeViewStepFactory, registerPlugin<RaveWelcomeViewStep>();)

// Widget that paints the background image scaled to fill (like Image.Stretch)
class BgWidget : public QWidget
{
public:
    explicit BgWidget(QWidget* parent = nullptr) : QWidget(parent) {}

    void setPixmap(const QPixmap& px) { m_pixmap = px; update(); }

protected:
    void paintEvent(QPaintEvent*) override
    {
        if (m_pixmap.isNull()) return;
        QPainter p(this);
        p.drawPixmap(rect(), m_pixmap);
    }

private:
    QPixmap m_pixmap;
};

RaveWelcomeViewStep::RaveWelcomeViewStep(QObject* parent)
    : Calamares::ViewStep(parent)
{
    // Default languages if not set via config
    m_localeIds = { "de", "en", "en_GB", "hu" };
}

RaveWelcomeViewStep::~RaveWelcomeViewStep()
{
    if (m_widget && m_widget->parent() == nullptr)
        delete m_widget;
}

QString RaveWelcomeViewStep::prettyName() const
{
    return tr("Welcome");
}

void RaveWelcomeViewStep::buildWidget()
{
    auto* bg = new BgWidget();
    bg->setSizePolicy(QSizePolicy::Expanding, QSizePolicy::Expanding);

    // Load welcome image from branding
    QString imgPath;
    if (Calamares::Branding::instance())
        imgPath = Calamares::Branding::instance()->imagePath(Calamares::Branding::ProductWelcome);

    if (!imgPath.isEmpty())
        bg->setPixmap(QPixmap(imgPath));

    // Bottom language bar
    auto* bar = new QFrame();
    bar->setFixedHeight(58);
    bar->setStyleSheet("background-color: rgba(43,43,43,200); border: none;");

    m_langCombo = new QComboBox(bar);
    m_langCombo->setFixedHeight(40);
    m_langCombo->setMinimumWidth(300);
    m_langCombo->setStyleSheet(
        "QComboBox {"
        "  background-color: rgba(43,43,43,180);"
        "  color: #ffffff;"
        "  border: none;"
        "  border-radius: 4px;"
        "  padding: 4px 12px;"
        "  font-size: 15px;"
        "}"
        "QComboBox::drop-down { border: none; width: 24px; }"
        "QComboBox QAbstractItemView {"
        "  background-color: rgba(43,43,43,160);"
        "  color: #ffffff;"
        "  selection-background-color: rgba(61,120,57,180);"
        "  border: none;"
        "  font-size: 15px;"
        "}"
        "QComboBox QAbstractItemView::item {"
        "  padding: 4px 12px;"
        "  min-height: 26px;"
        "}"
    );

    // Populate language model
    auto* model = new Calamares::Locale::TranslationsModel(m_localeIds, m_langCombo);
    m_langCombo->setModel(model);

    // Select current locale
    QLocale sys = QLocale::system();
    QString sysName = sys.name();
    m_currentLocaleIndex = 0;
    for (int i = 0; i < m_localeIds.size(); ++i)
    {
        if (m_localeIds[i] == sysName || sysName.startsWith(m_localeIds[i].left(2)))
        {
            m_currentLocaleIndex = i;
            break;
        }
    }
    // Default to "en"
    int enIdx = m_localeIds.indexOf("en");
    if (enIdx >= 0 && m_currentLocaleIndex == 0 && m_localeIds[0] != "en")
        m_currentLocaleIndex = enIdx;

    m_langCombo->setCurrentIndex(m_currentLocaleIndex);

    connect(m_langCombo, QOverload<int>::of(&QComboBox::activated),
            this, &RaveWelcomeViewStep::onLanguageChanged);

    auto* barLayout = new QHBoxLayout(bar);
    barLayout->setContentsMargins(16, 0, 16, 0);
    barLayout->addStretch();
    barLayout->addWidget(m_langCombo);
    barLayout->addStretch();

    auto* mainLayout = new QVBoxLayout(bg);
    mainLayout->setContentsMargins(0, 0, 0, 0);
    mainLayout->setSpacing(0);
    mainLayout->addStretch();
    mainLayout->addWidget(bar);

    m_widget = bg;
}

QWidget* RaveWelcomeViewStep::widget()
{
    if (!m_widget)
        buildWidget();
    return m_widget;
}

void RaveWelcomeViewStep::onLanguageChanged(int index)
{
    if (index < 0 || index >= m_localeIds.size())
        return;

    m_currentLocaleIndex = index;
    QString localeId = m_localeIds[index];

    // Install new translator - this changes the entire Calamares UI language
    Calamares::Locale::Translation::Id tid { localeId };
    Calamares::installTranslator(tid, brandingTranslationsPrefix());

    // Store locale in GlobalStorage for the installed system
    if (Calamares::JobQueue::instance())
    {
        Calamares::GlobalStorage* gs = Calamares::JobQueue::instance()->globalStorage();
        if (gs)
            gs->insert("localeLanguage", localeId);
    }
}

QString RaveWelcomeViewStep::brandingTranslationsPrefix() const
{
    if (Calamares::Branding::instance())
        return Calamares::Branding::instance()->translationsDirectory();
    return QString();
}

bool RaveWelcomeViewStep::isNextEnabled() const { return true; }
bool RaveWelcomeViewStep::isBackEnabled() const { return false; }
bool RaveWelcomeViewStep::isAtBeginning() const { return true; }
bool RaveWelcomeViewStep::isAtEnd() const { return true; }

Calamares::JobList RaveWelcomeViewStep::jobs() const { return {}; }

void RaveWelcomeViewStep::setConfigurationMap(const QVariantMap& config)
{
    if (config.contains("languages"))
    {
        QStringList langs;
        for (const auto& v : config.value("languages").toList())
            langs << v.toString();
        if (!langs.isEmpty())
            m_localeIds = langs;
    }
}
