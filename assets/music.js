/* Background music for the public pages (not the admin page).
   One song, assets/music.mp3, that carries on from where it was when the visitor moves between pages.
   A page includes this with <script src="assets/music.js" defer></script>. */
(() => {
  const SRC = "assets/music.mp3";
  const KEY_TIME = "a5-music-time", KEY_ON = "a5-music-on"; // kept for this browser tab only
  const store = {
    get(k) { try { return sessionStorage.getItem(k); } catch (e) { return null; } },
    set(k, v) { try { sessionStorage.setItem(k, v); } catch (e) { /* private mode: the music just restarts on each page */ } },
  };

  // The home page has the player in its own HTML and styles; other pages get it from here.
  let audio = document.getElementById("bg-music");
  let btn = document.getElementById("music-btn");
  if (!audio || !btn) {
    const style = document.createElement("style");
    style.textContent = `
      .music { position: fixed; right: max(16px, env(safe-area-inset-right)); bottom: max(16px, env(safe-area-inset-bottom)); z-index: 20;
        display: inline-flex; align-items: center; gap: 10px; min-height: 48px; padding: 0 18px 0 15px;
        border: 1px solid rgba(169, 222, 250, 0.45); border-radius: 999px; background: rgba(9, 18, 46, 0.88); color: #fff;
        font: 700 0.78rem/1 "Montserrat", system-ui, sans-serif; letter-spacing: 0.08em; text-transform: uppercase; cursor: pointer;
        box-shadow: 0 8px 24px rgba(4, 10, 30, 0.45); -webkit-backdrop-filter: blur(8px); backdrop-filter: blur(8px);
        transition: border-color 0.2s, background-color 0.2s, transform 0.2s; }
      .music[hidden] { display: none; }
      .music:hover { background: rgba(16, 30, 70, 0.92); }
      .music:active { transform: scale(0.96); }
      .music:focus-visible { outline: 3px solid #d9a441; outline-offset: 3px; }
      .music[aria-pressed="true"] { border-color: #d9a441; }
      .music .eq { display: flex; align-items: flex-end; gap: 3px; height: 18px; }
      .music .eq i { width: 3px; height: 100%; border-radius: 2px; background: currentColor; transform-origin: bottom; transform: scaleY(var(--rest)); transition: transform 0.3s, background-color 0.2s; }
      .music .eq i:nth-child(1) { --rest: 0.35; --d: 0.9s; }
      .music .eq i:nth-child(2) { --rest: 0.7; --d: 0.7s; }
      .music .eq i:nth-child(3) { --rest: 0.5; --d: 1.05s; }
      .music .eq i:nth-child(4) { --rest: 0.25; --d: 0.8s; }
      .music[aria-pressed="true"] .eq i { background: #d9a441; animation: a5-eq var(--d) ease-in-out infinite alternate; }
      .music[aria-pressed="true"] .eq i:nth-child(2) { animation-delay: -0.3s; }
      .music[aria-pressed="true"] .eq i:nth-child(3) { animation-delay: -0.55s; }
      .music[aria-pressed="true"] .eq i:nth-child(4) { animation-delay: -0.15s; }
      @keyframes a5-eq { 0% { transform: scaleY(0.2); } 35% { transform: scaleY(1); } 65% { transform: scaleY(0.45); } 100% { transform: scaleY(0.85); } }
      @media (max-width: 639px) {
        .music { width: 48px; padding: 0; justify-content: center; }
        .music .music-label { position: absolute; width: 1px; height: 1px; overflow: hidden; clip-path: inset(50%); white-space: nowrap; }
      }
      @media (prefers-reduced-motion: reduce) {
        .music[aria-pressed="true"] .eq i { animation: none; transform: scaleY(0.8); }
      }`;
    document.head.append(style);

    audio = document.createElement("audio");
    audio.id = "bg-music"; audio.src = SRC; audio.preload = "metadata"; audio.loop = true;
    btn = document.createElement("button");
    btn.className = "music"; btn.id = "music-btn"; btn.type = "button"; btn.hidden = true;
    btn.setAttribute("aria-pressed", "false");
    const eq = document.createElement("span");
    eq.className = "eq"; eq.setAttribute("aria-hidden", "true");
    eq.append(...[0, 1, 2, 3].map(() => document.createElement("i")));
    const text = document.createElement("span");
    text.className = "music-label"; text.textContent = "Play music";
    btn.append(eq, text);
    document.body.append(audio, btn);
  }
  const label = btn.querySelector(".music-label");
  audio.volume = 0.6;

  function render(playing) {
    btn.setAttribute("aria-pressed", String(playing));
    label.textContent = playing ? "Pause music" : "Play music";
    document.body.classList.toggle("music-on", playing);
  }

  // Show the button only once the file is actually there.
  const reveal = () => { btn.hidden = false; };
  if (audio.readyState >= 1) reveal(); else audio.addEventListener("loadedmetadata", reveal, { once: true });
  audio.addEventListener("error", () => { btn.hidden = true; render(false); });
  audio.addEventListener("play", () => render(true));
  audio.addEventListener("pause", () => render(false));

  // Carry on from where the song was on the previous page.
  const resumeAt = parseFloat(store.get(KEY_TIME));
  const wasOn = store.get(KEY_ON); // "1" playing, "0" the visitor paused it, null = first page of this visit
  function seek() {
    if (resumeAt > 0 && isFinite(audio.duration) && resumeAt < audio.duration) audio.currentTime = resumeAt;
  }
  if (audio.readyState >= 1) seek(); else audio.addEventListener("loadedmetadata", seek, { once: true });

  // Remember the position as it plays and when the visitor leaves the page.
  let lastSaved = 0;
  const save = () => { if (!audio.paused || audio.currentTime > 0) store.set(KEY_TIME, String(audio.currentTime)); };
  audio.addEventListener("timeupdate", () => { if (Math.abs(audio.currentTime - lastSaved) >= 1) { lastSaved = audio.currentTime; save(); } });
  addEventListener("pagehide", save);

  // Browsers block sound until the visitor interacts with the page, so start on the first click, tap or key press.
  const events = ["click", "touchend", "keydown"];
  const stopListening = () => events.forEach((e) => document.removeEventListener(e, startOnFirstInteraction, true));
  function start() {
    return audio.play().then(() => { store.set(KEY_ON, "1"); stopListening(); });
  }
  function startOnFirstInteraction(e) {
    if (btn.contains(e.target)) { stopListening(); return; } // the button handles its own click
    if (audio.error || !audio.paused) { stopListening(); return; }
    start().catch(() => render(false));
  }

  if (wasOn !== "0") { // the visitor hasn't paused it: play, or wait for their first tap if the browser insists
    events.forEach((e) => document.addEventListener(e, startOnFirstInteraction, true));
    if (wasOn === "1") start().catch(() => { /* blocked until a tap; the listeners above take over */ });
  }

  btn.addEventListener("click", () => {
    stopListening();
    if (audio.paused) start().catch(() => render(false));
    else { audio.pause(); store.set(KEY_ON, "0"); save(); }
  });
})();
