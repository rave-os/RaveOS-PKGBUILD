#include "DesktopBackend.h"

DesktopBackend::DesktopBackend(QObject* parent)
    : QObject(parent)
{}

void DesktopBackend::setDesktops(const QVariantList& desktops)
{
    m_desktops = desktops;
    m_selectedIndex = -1;
    emit desktopsChanged();
    emit selectedIndexChanged();
}

void DesktopBackend::selectDesktop(int index)
{
    if (index == m_selectedIndex)
        return;
    if (index < 0 || index >= m_desktops.size())
        return;
    m_selectedIndex = index;
    emit selectedIndexChanged();
    emit selectionMade();
}

QStringList DesktopBackend::selectedPackages() const
{
    if (m_selectedIndex < 0 || m_selectedIndex >= m_desktops.size())
        return {};
    const QVariantMap desktop = m_desktops[m_selectedIndex].toMap();
    QStringList pkgs;
    for (const auto& v : desktop.value("packages").toList())
        pkgs << v.toString();
    return pkgs;
}
