============================================================
  XRay Simulator 1.0.0  —  Istruzioni di avvio (macOS)
============================================================

L'app NON è firmata con un certificato Apple (no code signing /
notarizzazione). Al primo avvio macOS Gatekeeper la bloccherà
con un messaggio del tipo:

  "Impossibile aprire «XRay-Simulator.app» perché proviene da
   uno sviluppatore non identificato."

QUESTO È NORMALE. Per avviarla la prima volta:

  1. Nel Finder, apri la cartella "builds".
  2. Fai CLICK DESTRO (o Ctrl + click) su "XRay-Simulator.app".
  3. Scegli "Apri" dal menu contestuale.
  4. Nella finestra di avviso, premi di nuovo "Apri".

Da quel momento l'app si avvierà normalmente con un doppio click.

In alternativa, se il blocco persiste:
  Impostazioni di Sistema → Privacy e Sicurezza → scorri fino a
  "Sicurezza" → premi "Apri comunque" accanto al nome dell'app.

Oppure da Terminale (rimuove l'attributo di quarantena):
  xattr -dr com.apple.quarantine "builds/XRay-Simulator.app"

------------------------------------------------------------
  Requisiti
------------------------------------------------------------
  • macOS 11 (Big Sur) o successivo
  • Mac con Apple Silicon (M1/M2/M3...) — build nativa arm64
  • Risoluzione consigliata: 1920×1080 (finestra fissa)

------------------------------------------------------------
  Controlli
------------------------------------------------------------
  SPAZIO        Ferma / riavvia il nastro
  APPROVA       Bagaglio sicuro (a nastro fermo)
  RESPINGI      Bagaglio con minaccia (a nastro fermo)
  iCMORE ON/OFF Mostra il box automatico sulle minacce
  F3            Monitor prestazioni (solo build di debug)
============================================================
