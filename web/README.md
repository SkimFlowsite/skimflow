# Skimflow — Website

Source of the live site at **[skimflow.site](https://skimflow.site)** (and `/docs`).

Self-contained static site — no build step.

| File         | Purpose                                             |
| ------------ | --------------------------------------------------- |
| `index.html` | Landing page (hero, mechanism, security, FAQ)       |
| `docs.html`  | Documentation / whitepaper page (`/docs`)           |
| `assets/`    | Logo mark, diagram, OG image, favicon, X assets     |

## Local preview

```bash
cd web
python3 -m http.server 8080
# open http://localhost:8080
```

## Deploy

Served statically (Caddy) from `skimflow.site`. Asset paths are root-relative
(`/assets/*`) so the same files serve at the domain root.
