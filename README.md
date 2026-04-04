# 📦 StockSense

> Multi-module inventory and management ecosystem with mobile app, web admin, and database tooling.

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-Mobile_App-02569B?logo=flutter&logoColor=white)
![PHP](https://img.shields.io/badge/PHP-Web_Admin-777BB4?logo=php&logoColor=white)
![MySQL](https://img.shields.io/badge/SQL-Database_Scripts-4479A1?logo=mysql&logoColor=white)

Mobile + Web + SQL | Modular architecture | Practical business focus

</div>

---

## 🚀 Overview

StockSense is a modular project for inventory-oriented workflows, combining:

- A **Flutter mobile application** for day-to-day operations.
- A **PHP web admin** for dashboard and back-office control.
- A **database package** with schemas, reports, optimizations, and backup scripts.

The repository is structured to support iterative development and future scaling.

### Why StockSense?

- **End-to-end scope**: Covers app, web, and data layers in one repository.
- **Learning + production mindset**: Built as a practical system with clear module boundaries.
- **Extensible base**: Enables adding analytics, integrations, and automation later.

---

## ✨ Features

- Cross-platform mobile app foundation in Flutter.
- Web admin panel in PHP for management tasks.
- SQL scripts for setup, reporting, optimization, and backup workflows.
- Documentation assets for onboarding and user guidance.

---

## 🏗️ Architecture

StockSense follows a module-oriented architecture:

| Module | Purpose | Main Tech |
|---|---|---|
| `app_mobile/` | Mobile client and user interactions | Flutter / Dart |
| `web-admin/` | Admin dashboard and web workflows | PHP / HTML / CSS |
| `database/` | Data model, reports, procedures, optimization scripts | SQL |
| `docs/` | User-facing and project documentation artifacts | PDF / Assets |

This separation helps maintain focus, ownership, and clean evolution per module.

---

## 📋 Requirements

### Mobile (`app_mobile`)

- Flutter SDK (stable channel)
- Dart SDK (bundled with Flutter)
- Android Studio or Xcode (depending on target platform)

### Web Admin (`web-admin`)

- PHP 8+
- Apache or Nginx
- MySQL / MariaDB

### Database (`database`)

- SQL engine compatible with provided scripts (recommended: MySQL/MariaDB)

---

## 🛠️ Installation

### 1) Clone repository

```bash
git clone https://github.com/RamsesCB/StockSense.git
cd StockSense
```

### 2) Setup database (suggested order)

Run scripts in `database/` according to your environment:

1. `script_inicial.sql`
2. `schema_v1.sql` and/or `schema_v2.sql`
3. `datos_prueba.sql`
4. `consultas_basicas.sql`, `reportes.sql`, `optimizaciones.sql`

### 3) Run mobile app

```bash
cd app_mobile
flutter pub get
flutter run
```

### 4) Run web admin

Configure your local PHP server and point document root to `web-admin/`.

---

## 📖 Usage

Typical workflow:

1. Initialize and verify database schema.
2. Use mobile app for operational data flow.
3. Use web admin for management and visibility.
4. Run reporting and optimization SQL scripts as needed.

---

## 📁 Project Structure

```text
StockSense/
├── app_mobile/
│   ├── lib/
│   ├── test/
│   ├── android/
│   ├── ios/
│   └── pubspec.yaml
├── web-admin/
│   ├── dashboard.php
│   ├── Login.php
│   └── css/
├── database/
│   ├── script_inicial.sql
│   ├── schema_v1.sql
│   ├── schema_v2.sql
│   ├── datos_prueba.sql
│   ├── reportes.sql
│   ├── optimizaciones.sql
│   └── backup_procedure.sql
└── docs/
    ├── manual_usuario.pdf
    └── branding (logos).zip
```

---

## 🔧 Configuration Notes

- Keep environment-specific credentials outside the repository.
- Version SQL migrations intentionally and document applied order.
- Maintain consistent naming between mobile models and database schema.

---

## 🧭 Roadmap Suggestions

- Add CI checks for Flutter and SQL linting.
- Introduce API service layer between mobile/web and database.
- Add automated backup/restore validation scripts.

---

## 🤝 Contributing

Contributions are welcome.

1. Fork the repository.
2. Create a branch for your feature or fix.
3. Keep commits focused and descriptive.
4. Open a pull request with clear context and testing notes.

---

## 📄 License

No license file is currently defined. Consider adding one (MIT is a common option).

---

## 🙏 Acknowledgments

- Built as a practical multi-layer software engineering exercise.
- Designed to evolve from prototype workflows into a robust system.
