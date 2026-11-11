# After 5 Pickleball Club — Mini Tournament site

A one-page site for the 1st Official Mini Tournament. "Join the Club" opens the member information form — a bottom drawer on phones, a centered popup on larger screens — and each submission is saved to Supabase, including an optional team logo.

- `index.html` — the whole site (styles and script are inside it)
- `assets/poster.png` — the event poster (linked in the footer)
- `assets/share.jpg` — the picture shown when the link is shared in Messenger, Facebook, etc.
- `matchday.html` — the Match Day posters, one per doubles match (2 vs 2)
- `admin.html` — the officers' page: registrations and the Match Day match-ups
- `supabase/setup.sql` — creates the members table, the team logo storage and the matches table

## Connect the form to Supabase

Until this is done, the form shows "This form isn't connected to the database yet" when someone submits.

1. Create a free project at [supabase.com](https://supabase.com) (any name; pick the Singapore region for the Philippines).
2. In the project, open **SQL Editor → New query**, paste in the contents of `supabase/setup.sql`, and click **Run**.
3. Open **Project Settings → API** (or the **Connect** button) and copy:
   - the **Project URL** (looks like `https://abcdefgh.supabase.co`)
   - the **anon / publishable key** — *not* the `service_role` / secret key
4. In `index.html`, find `SUPABASE_URL` and `SUPABASE_KEY` near the bottom and paste the two values between the quotes.

The anon key is meant to be public. The setup script only lets it add registrations and upload logos; it can't read anyone's details.

## See the registrations: the admin page

`admin.html` lists everyone who registered, 20 per page, with search, a paid / not-paid filter, each team logo with a **Download logo** button, and **Export CSV**. Nothing on the main page links to it — open it by typing the address, e.g. `https://your-site.example/admin.html`. Officers can also press **Confirm registration** on an entry (and undo it); that is the only thing the page can change.

It needs a login, and only accounts you list as admins can see anything:

1. Run `supabase/setup.sql` again in the **SQL Editor** (safe to re-run; it adds the admin rules).
2. In Supabase, open **Authentication → Users → Add user → Create new user**. Enter the officer's email and a password, and keep **Auto Confirm User** ticked.
3. In the **SQL Editor**, run this with that email:

   ```sql
   insert into public.admins (user_id)
     select id from auth.users where email = 'officer@example.com'
     on conflict do nothing;
   ```

Repeat steps 2–3 for each officer. To remove someone, delete their user under **Authentication → Users**.

You can also see the raw data in Supabase under **Table Editor → members** and **Storage → team-logos**.

## Match Day posters

`matchday.html` shows a poster for every match: the photos and names of the two players on each side, the date, time and court. Each poster has a **Save image** button that downloads it as a picture (1080 × 1350, ready for Facebook or Messenger). The home page links to it under the Join button and in the footer.

To put real matches on it:

1. Run `supabase/setup.sql` again in the **SQL Editor** (safe to re-run; it adds the `matches` table).
2. Sign in to `admin.html` and open **Match Day posters**.
3. Choose two players for Team A and two for Team B. **Name on poster** starts as the player's full name — shorten it to a first name or nickname if you like. Each player's photo is the image they uploaded when they registered; a player with no image gets their initial instead.
4. Set the date, time, round and court, then press **Add match**. **Delete** takes a poster off the page.

Until the first match is added, the page shows one sample poster with made-up names.

## Background music

`assets/music.mp3` starts playing the first time a visitor clicks, taps or presses a key anywhere on the page (browsers don't allow music to start before that). The music button in the bottom-right corner pauses and resumes it. To change the song, replace that file and keep the name. If the file is removed, the button disappears.

## Share a link that opens the form

Add `#join` to the site address (e.g. `https://your-site.example/#join`) and the form opens straight away.

## Where the site lives

The site is published with GitHub Pages from the `main` branch of `EverAfterWeddingandEvents/after5-minitournament`, at https://after5-minitournament.everafterweddingsandevent.com (set by the `CNAME` file). The admin page is at `/admin.html`.

If you ever move it to another address, update `CNAME` and the `og:url` and `og:image` addresses near the top of `index.html`, or shared links will lose their picture. If an old preview keeps showing, paste the link into Facebook's Sharing Debugger and press **Scrape Again**.

## Preview locally

Open `index.html` in a browser, or run `python3 -m http.server` in this folder and visit http://localhost:8000.
