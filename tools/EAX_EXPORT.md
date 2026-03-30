# EAX plugin exporter

Run the packaging exporter from the repo root:

```bash
python tools/export_eax_plugins.py --output dist/eax_ship
```

One-off export:

```bash
python tools/export_eax_plugins.py --output dist/eax_ship --plugin EAXPaladinProtection
```

The exporter creates a package directory plus a matching `.zip` for each plugin.
