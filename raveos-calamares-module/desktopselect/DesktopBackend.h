#pragma once
#include <QObject>
#include <QStringList>
#include <QVariantList>

class DesktopBackend : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList desktops READ desktops NOTIFY desktopsChanged)
    Q_PROPERTY(int selectedIndex READ selectedIndex NOTIFY selectedIndexChanged)

public:
    explicit DesktopBackend(QObject* parent = nullptr);

    QVariantList desktops() const { return m_desktops; }
    int selectedIndex() const { return m_selectedIndex; }

    void setDesktops(const QVariantList& desktops);
    QStringList selectedPackages() const;

    Q_INVOKABLE void selectDesktop(int index);

signals:
    void desktopsChanged();
    void selectedIndexChanged();
    void selectionMade();

private:
    QVariantList m_desktops;
    int m_selectedIndex = -1;
};
