**Layout-i Adaptive & Mbështetja për Tablet (Master–Detail, Clamping)**

- **Përmbledhje:**: Aplikacioni përdor sjellje të përshtatshme për ekranet e mëdha duke aktivizuar një sidebar/side-nav në breakpoint rreth `600px`. Në mënyrë praktike ka dy modele: (1) HomePage shfaq një `side navigation + PageView` kur gjerësia > 600 (master–detail-stil për navigimin kryesor), dhe (2) `QuranScriptView` shton një `sideBarOfSurahAndAyah` kur `isLandScape` (width > 600) për të kombinuar listën e sureve/ayah-ve me pamjen e leximt.

- **A përdor Master–Detail? Si realizohet navigimi?**
  - Po — sjellja Master–Detail është e prezente në dy vende kryesore:
    - `HomePage` ndryshon nga `BottomNavigationBar` në një panel anësor (sidebar) kur `width > 600`. Implementimi: [lib/src/screen/home/home_page.dart](lib/src/screen/home/home_page.dart#L340-L360) (shih `isSideNav`, `navsInSidebar`, `drawerInSidebar`).
    - `QuranScriptView` përdor `isLandScape = width > 600` për të treguar `sideBarOfSurahAndAyah` pranë përmbajtjes së leximt; në modalitetin e gjerë veprimet mbi listën (zgjedhja e ayah/surah) zakonisht bëhen në vend pa navigim të ri — por ndryshimi i surah bëhet me `Navigator.pushReplacement` në rastin e zgjedhjes së surah-it të ri (shih më poshtë). Vini re: [lib/src/screen/quran_script_view/quran_script_view.dart](lib/src/screen/quran_script_view/quran_script_view.dart#L216-L256) dhe [lib/src/screen/quran_script_view/quran_script_view.dart](lib/src/screen/quran_script_view/quran_script_view.dart#L320-L344).

- **Si realizohet navigimi mes listës së sureve dhe faqes së leximit në ekran të gjerë?**
  - Në `QuranScriptView`:
    - Kur përdoruesi zgjedh një `ayah` brenda sidebar-it të ayah-ve, shikohet metoda `scrollToAyah(...)` dhe ndryshohet gjendja lokale (`AyahByAyahInScrollInfoCubit`) — kjo nuk shtyp rrugën (route) e navigimit, pra është një përditësim në vend.
    - Kur përdoruesi zgjedh një `surah` nga lista anësore, kodi përdor `Navigator.pushReplacement(...)` për të krijuar një `QuranScriptView` të ri me `startKey` të ri — kjo zëvendëson rreshtin aktual në historikun e navigimit (pra nuk shton një entry të ri në back stack). Shiko: [lib/src/screen/quran_script_view/quran_script_view.dart#L320-L344].

- **A ka kufizime në gjerësinë e tekstit (Clamping / Max Width)?**
  - Për përmbajtjen kryesore të leximt (rendererët `Uthmani`/`NonTajweed`), nuk gjeta një `maxWidth` global ose `ConstrainedBox` që të bëjë clamping të tekstit për të limituar gjatësinë e rreshtave; `Text.rich` përdor `fontSize` dhe `fontFamily` por elementi merr hapësirë të disponueshme. Shënim: ekziston një clamping i vogël për dialogun e ndarjes (`share_bottom_dialog.dart`) me `maxWidth: 500`. Shiko: [lib/src/widget/ayah_by_ayah/share_bottom_dialog.dart](lib/src/widget/ayah_by_ayah/share_bottom_dialog.dart#L196-L206).
  - Përmbledhim: nuk ka një max-width/line-clamp të centralizuar për përmirësimin e lexueshmërisë në tablet — përmbajtja e leximt shtrihet në hapësirën e disponueshme. Vetëm sidebars kanë gjerësi fikse (p.sh., `isJustDrawerIcon ? 70 : 270`).

- **Si ndryshon UI (NavigationRail vs BottomNavigationBar) në breakpoints?**
  - Implementimi nuk përdor `NavigationRail` nga Flutter, por realizon një sidebar personal me butona (funksi `navsInSidebar` / `desktopNav`) dhe në praktike zëvendëson `BottomNavigationBar` kur `width > 600`.
  - Breakpoints kryesorë gjetur në kod:
    - `width > 600` → aktivizon side navigation/dual-pane (HomePage `isSideNav` ; QuranScriptView `isLandScape`). Shiko: [lib/src/screen/home/home_page.dart#L336-L344] dhe [lib/src/screen/quran_script_view/quran_script_view.dart#L216-L224].
    - `width < 800` → përdoret `isJustDrawerIcon` për të ndryshuar pamjen e sidebar (ikonë e ngushtë vs panel i plotë). Shiko: [lib/src/screen/home/home_page.dart#L352-L358].
    - Disa ekrane e përdorin breakpoint më të madh (p.sh. `audio_page.dart` përdor `width > 1000` për sjellje të ndryshme). Shiko: [lib/src/screen/audio/audio_page.dart#L56-L72].

- **Si menaxhohet historia e navigimit në modalitetin Master–Detail?**
  - Zgjedhjet e brendshme (p.sh., zgjedhja e një ayah brenda të njëjtës `QuranScriptView`) nuk shtojnë entry në stack; kodi thjesht scroll-on/aktualizon Cubits (`AyahByAyahInScrollInfoCubit`, `AyahToHighlight`, `AyahKeyCubit`). Kjo mban historikun e navigimit të mëthin të qartë (back = dalja nga pamja aktuale), pa entries të shumta.
  - Zgjedhja e një `surah` në sidebar përdor `Navigator.pushReplacement(...)` për të krijuar një `QuranScriptView` të ri — kjo zëvendëson rreshtin aktual në historikun e navigimit (pra nuk lejon rikthim në atë view specifik duke përdorur butonin `back`). Shiko: [lib/src/screen/quran_script_view/quran_script_view.dart#L320-L344].

- **Pikëvështrime dhe rekomandime të shpejta:**
  - Për përmirësim të lexueshmërisë në tableta, shtoni një `maxWidth` (p.sh., 700–900px) rreth `Text.rich` ose vendosni për një dy-kolumnë me clamping të rreshtave për tekste të gjata (p.sh., për përkthime).
  - Konsideroni përdorimin e `NavigationRail` ose `TwoPane` (Windows/Android Jetpack Compose) për të përfituar nga sjelljet native dhe aksesueshmëria; aktualisht kodi implementon komponent të personalizuar që funksionon mirë, por `NavigationRail` do të jepte sjellje të paracaktuara dhe fokus/aksesibilitet.
  - Nëse dëshironi që zgjedhja e `surah` të shtojë entry në historikun (p.sh., për t'u kthyer lehtë), ndryshoni `Navigator.pushReplacement(...)` në `Navigator.push(...)` ose implementoni një mekanizëm për të regjistruar historikun e brendshëm.

---

Referenca kryesore: `HomePage` (në [lib/src/screen/home/home_page.dart](lib/src/screen/home/home_page.dart#L336-L360)) dhe `QuranScriptView` (në [lib/src/screen/quran_script_view/quran_script_view.dart](lib/src/screen/quran_script_view/quran_script_view.dart#L216-L256) dhe [lib/src/screen/quran_script_view/quran_script_view.dart](lib/src/screen/quran_script_view/quran_script_view.dart#L320-L344)).

Dokument u krijua pas skanimeve të skederëve të layout-it dhe renderer-ëve.
