#include "DesktopSelectViewStep.h"

#include <QDir>
#include <QFile>
#include <QSet>
#include <QVBoxLayout>
#include <QQuickWidget>
#include <QQmlContext>
#include <QQmlEngine>

#include <GlobalStorage.h>
#include <JobQueue.h>

CALAMARES_PLUGIN_FACTORY_DEFINITION(DesktopSelectViewStepFactory, registerPlugin<DesktopSelectViewStep>();)

DesktopSelectViewStep::DesktopSelectViewStep(QObject* parent)
    : Calamares::ViewStep(parent)
    , m_backend(new DesktopBackend(this))
{
    connect(m_backend, &DesktopBackend::selectionMade, this, [this]() {
        emit nextStatusChanged(true);
    });
}

DesktopSelectViewStep::~DesktopSelectViewStep()
{
    if (m_widget && m_widget->parent() == nullptr)
        delete m_widget;
}

QString DesktopSelectViewStep::prettyName() const
{
    return tr("Desktop");
}

void DesktopSelectViewStep::buildWidget()
{
    m_widget = new QWidget();
    auto* layout = new QVBoxLayout(m_widget);
    layout->setContentsMargins(0, 0, 0, 0);

    m_quickWidget = new QQuickWidget();
    m_quickWidget->setResizeMode(QQuickWidget::SizeRootObjectToView);

    QString modulePath = QStringLiteral("/usr/lib/calamares/modules/desktopselect/ui");
    if (!QDir(modulePath).exists())
        modulePath = QDir::currentPath() + QStringLiteral("/desktopselect/ui");

    m_quickWidget->engine()->addImportPath(modulePath);
    m_quickWidget->rootContext()->setContextProperty("backend", m_backend);

    QString qmlPath = QStringLiteral("/usr/lib/calamares/modules/desktopselect/ui/desktopselect.qml");
    if (!QFile::exists(qmlPath))
        qmlPath = QDir::currentPath() + QStringLiteral("/desktopselect/ui/desktopselect.qml");

    m_quickWidget->setSource(QUrl::fromLocalFile(qmlPath));
    layout->addWidget(m_quickWidget);
}

QWidget* DesktopSelectViewStep::widget()
{
    if (!m_widget)
        buildWidget();
    return m_widget;
}

bool DesktopSelectViewStep::isNextEnabled() const
{
    return m_backend && m_backend->selectedIndex() >= 0;
}

bool DesktopSelectViewStep::isBackEnabled() const { return true; }
bool DesktopSelectViewStep::isAtBeginning() const { return true; }
bool DesktopSelectViewStep::isAtEnd() const { return true; }

Calamares::JobList DesktopSelectViewStep::jobs() const { return {}; }

void DesktopSelectViewStep::onLeave()
{
    if (!m_backend || m_backend->selectedIndex() < 0)
        return;

    // Merge mandatory + selected desktop packages, deduplicated
    QStringList combined = m_mandatoryPackages + m_backend->selectedPackages();
    QStringList unique;
    QSet<QString> seen;
    for (const QString& pkg : combined) {
        if (!seen.contains(pkg)) {
            seen.insert(pkg);
            unique << pkg;
        }
    }

    QVariantMap op;
    op[QStringLiteral("install")] = unique;
    QVariantList ops;
    ops.append(op);

    if (!Calamares::JobQueue::instance())
        return;
    auto* gs = Calamares::JobQueue::instance()->globalStorage();
    if (gs)
        gs->insert(QStringLiteral("packageOperations"), ops);
}

void DesktopSelectViewStep::setConfigurationMap(const QVariantMap& config)
{
    m_mandatoryPackages.clear();
    for (const auto& v : config.value("mandatory_packages").toList())
        m_mandatoryPackages << v.toString();

    QVariantList desktops;
    for (const auto& item : config.value("desktops").toList())
        desktops << item;

    m_backend->setDesktops(desktops);
}
