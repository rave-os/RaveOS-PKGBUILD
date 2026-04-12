  # RaveOS-PKGBUILD

  RaveOS PKGBUILD repository.

  Ez a repository a RaveOS-hoz használt PKGBUILD-öket, csomagolási fájlokat, theme csomagokat és
  telepítéshez szükséges payloadokat tartalmazza. A cél az, hogy a rendszerhez tartozó saját csomagok külön,
  átláthatóan és egyszerűen buildelhetők, karbantarthatók és repository-ba tehetők legyenek.

  ## Tartalom

  A repository-ban megtalálhatók többek között:

  - rendszerhez tartozó egyedi PKGBUILD-ek
  - desktop theme csomagok


  ## Build

  A csomagok külön mappákból buildelhetők.

  Példa:

  ```bash
  cd theme/themes/gnome
  makepkg -sf

  A kész csomag a build/ mappába kerül.

  ## Cél

  A repository célja, hogy a RaveOS saját csomagjai és desktop payloadjai:

  - egyszerűen kezelhetők legyenek
  - külön frissíthetők legyenek
  - repo-ba tehetők legyenek
  - ISO build és telepítés alatt is használhatók legyenek

  ## Megjegyzés

  A repository folyamatosan változik, ezért egyes csomagok vagy payloadok még fejlesztés alatt állhatnak.
