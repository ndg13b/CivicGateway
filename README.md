# Civic Gateway

A simple, nonpartisan website that lets people select their city and see upcoming
elections or their current elected officials, with links to contact info and
(where available) social media. If there's no upcoming election, it shows current
officeholders instead.

The name is a nod to St. Louis (the "Gateway" city) and to the idea of a gateway —
a way in — to local civic information. Coverage starts in St. Louis County, Missouri
(Maryland Heights, Creve Coeur, and Bridgeton) and is designed to expand to more areas.

## How it works

The live site is a single HTML file (`index.html`) — no server or database required.
All the city information lives in one place: the `BALLOT_DATA` object near the top of
the script. The page reads that data to build the dropdown menus and display results.

## Moving to a database (in progress)

To let the site scale past a handful of hand-edited cities, we're migrating the data
into a Supabase (Postgres) database. See [`DATABASE-PLAN.md`](DATABASE-PLAN.md) for
the full plan:

- [`schema.sql`](schema.sql) — the table definitions and Row Level Security policies
- [`seed.sql`](seed.sql) — the 3 current cities, converted into insertable rows
- [`db-test.html`](db-test.html) — the database-backed version of the site. It
  fetches from Supabase instead of `BALLOT_DATA` and carries the new site design
  (shared stylesheet and logic live in [`assets/`](assets/)). Once verified, the
  plan is to make this the main site.

`index.html` is untouched by this work until the database version is verified to
match it exactly.

## Adding or updating a city

1. Open `index.html` in any text editor.
2. Find the `BALLOT_DATA` section near the top of the `<script>`.
3. Copy an existing city block (or the commented `TEMPLATE` block) and fill in
   verified information from the city's official website.
4. Save and refresh. The dropdowns update automatically.

Two optional fields add richer features:
- `resources` on a race makes its title clickable, linking to debate/forum videos.
- `interviews` on a person adds an interview/coverage section to their page.

Please use official, verifiable sources and keep all entries nonpartisan.

## Contributing

Corrections and new cities are welcome. Because this is voter information, accuracy
matters — cite the official source for any data you add.

## License

Code is released under the MIT License (see `LICENSE`).
