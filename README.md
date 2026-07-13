# Civic Gateway

A simple, nonpartisan website that lets people select their city and see upcoming
elections or their current elected officials, with links to contact info and
(where available) social media. If there's no upcoming election, it shows current
officeholders instead.

The name is a nod to St. Louis (the "Gateway" city) and to the idea of a gateway —
a way in — to local civic information. Coverage starts in St. Louis County, Missouri
(Maryland Heights, Creve Coeur, and Bridgeton) and is designed to expand to more areas.

Live at **[civicgateway.org](https://civicgateway.org/)**.

## How it works

The site is static (hosted on GitHub Pages) and reads its data from a Supabase
(PostgreSQL) database at page load:

- [`index.html`](index.html) — the page shell and Supabase configuration
- [`assets/styles.css`](assets/styles.css) — the design system
- [`assets/app.js`](assets/app.js) — data loading and rendering
- [`assets/fallback-data.json`](assets/fallback-data.json) — an offline snapshot
  served automatically if the database is unreachable, so the site degrades to
  "recently saved data" instead of an error

The database itself is defined in:

- [`schema.sql`](schema.sql) — table definitions and Row Level Security policies
  (public key can read everything, write nothing)
- [`seed.sql`](seed.sql) — the current cities as insertable rows
- [`DATABASE-PLAN.md`](DATABASE-PLAN.md) — the design rationale

## Adding or updating a city

City data lives in the Supabase database (tables: `jurisdictions`, `officials`,
`elections`, `races`, `candidates`, `resources`). To add or update a city:

1. Add/edit the rows in Supabase (Table Editor, or SQL like `seed.sql`).
2. Update `assets/fallback-data.json` to match, so the offline snapshot stays
   current.
3. Verify against the city's official website — this is voter information, and
   accuracy matters. Cite the official source for any data you add.

Two optional features are supported by the data model:
- `resources` rows with kind `debate`/`info` attached to a race add a
  "Debates & info" button to that ballot item.
- `resources` rows with kind `interview` attached to a candidate add an
  "Interviews & coverage" section to their page.

## Development workflow

- **`main`** is the live site — GitHub Pages serves it directly, and it's
  protected: changes land via reviewed pull requests.
- **`dev`** is the working branch — develop there (or on feature branches),
  then open a PR from `dev` to `main` when it's ready to go live.

## Contributing

Corrections and new cities are welcome. Because this is voter information, accuracy
matters — cite the official source for any data you add. Use the
[issue tracker](https://github.com/ndg13b/CivicGateway/issues) to report corrections.

## License

Code is released under the MIT License (see `LICENSE`).
