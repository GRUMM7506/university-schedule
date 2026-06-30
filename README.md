# University Process Management System

Полноценная учебная ERP-система для вуза: клиент на **Flutter 3.x** (Material 3, glassmorphism-дизайн) и backend на **FastAPI** поверх **PostgreSQL**, с JWT-аутентификацией, refresh-токенами, гостевым доступом и гранулярной системой прав доступа (роли + индивидуальные разрешения по пользователю).

## Содержание

- [Архитектура](#архитектура)
- [Технологический стек](#технологический-стек)
- [Структура проекта](#структура-проекта)
- [Роли и права доступа](#роли-и-права-доступа)
- [Требования](#требования)
- [Установка — Backend](#установка--backend)
- [Установка — Flutter-клиент](#установка--flutter-клиент)
- [Запуск на разных платформах](#запуск-на-разных-платформах)
- [Сборка релизов](#сборка-релизов)
- [REST API](#rest-api)
- [Учётные записи](#учётные-записи)
- [Частые проблемы](#частые-проблемы)
- [Проверки](#проверки)

## Архитектура

```text
Flutter (Android / iOS / Web / Windows / macOS / Linux)
        │  REST + JWT
        ▼
   FastAPI backend
        │  SQLAlchemy 2.0 / Alembic
        ▼
   PostgreSQL
```

Прямого подключения Flutter к PostgreSQL нет — клиент работает только через REST API (`/api/...`) и JWT (access-токен в заголовке `Authorization: Bearer`, refresh-токен хранится на устройстве через `shared_preferences`).

## Технологический стек

**Backend**

- Python 3.11+ (разработка велась на 3.13)
- FastAPI 0.115, Uvicorn (standard) 0.34
- SQLAlchemy 2.0, Alembic 1.14
- PostgreSQL 14+ (драйвер `psycopg[binary]` 3.2)
- Pydantic 2.10 / pydantic-settings
- python-jose (JWT), passlib + bcrypt (хэширование паролей)

**Frontend**

- Flutter SDK с Dart **≥ 3.9.2** (это соответствует Flutter **3.35** и новее на stable-канале — проверяйте через `flutter --version`)
- provider (state management), go_router (навигация + guard-редиректы), dio (HTTP-клиент)
- data_table_2 (таблицы CRUD-экранов), intl, shared_preferences

## Структура проекта

```text
backend/
  alembic/
    versions/            # 0001…0006, линейная цепочка миграций
  app/
    api/
      routes.py           # все REST-эндпоинты
      crud_router.py       # фабрика CRUD-роутов для справочников
      deps.py               # JWT, проверка ролей и прав доступа
    core/                 # настройки (.env), JWT/пароли
    db/                   # SQLAlchemy engine/session
    models/               # ORM-модели + реестр прав (permissions.py)
    schemas/              # Pydantic-схемы
    services/             # generic CRUD-сервис
  seed.py                 # восстановление БД из дампа dbb_plain.sql
  requirements.txt
  .env.example
lib/
  core/                   # AppState, TTL-кэш для справочников
  models/                 # описания сущностей для generic CRUD-экранов
  providers/              # AuthProvider, EntityProvider (ChangeNotifier)
  services/                # ApiClient (dio), AuthService, EntityService...
  screens/                # Dashboard, Login, Gradebook, Schedule, Attendance,
                          # Performance, Profile(+Setup), UserManagement...
  widgets/                # AppShell (навигация), GlassPanel, EntityFormDialog,
                          # PermissionGate, GroupPicker, ScheduleFormDialog
  theme/                  # тёмная/светлая тема, ThemeController
  routes/                 # GoRouter + redirect-guard по ролям/правам
```

## Роли и права доступа

В системе четыре роли — `Admin`, `Teacher`, `Student`, `Guest`. У каждой роли есть набор прав по умолчанию (`app/models/permissions.py`), а у Admin'а в `users-admin` есть UI для выдачи/отзыва индивидуальных прав конкретному пользователю поверх ролевых дефолтов (таблица `UserPermission`, эндпоинты `/api/permissions/...`). Admin всегда имеет полный доступ независимо от индивидуальных настроек.

```text
Admin   — полный доступ ко всем разделам и CRUD-операциям
Teacher — расписание/посещаемость/успеваемость/журнал + просмотр части
          справочников; набор можно расширять через панель прав
Student — личный кабинет: расписание, посещаемость, успеваемость
Guest   — ограниченный демо-доступ (дашборд, расписание), вход без пароля
          через кнопку «Войти как гость»
```

Frontend скрывает в меню те разделы, на которые у пользователя нет прав, а `GoRouter`-redirect и backend (`require_permission`) независимо блокируют прямой переход по URL — то есть проверка дублируется на обоих уровнях.

## Требования

| Компонент   | Версия                                   |
|-------------|-------------------------------------------|
| Python      | 3.11 – 3.13                                |
| PostgreSQL  | 14+                                        |
| Flutter SDK | stable-канал с Dart ≥ 3.9.2 (Flutter 3.35+)|
| Git         | любая актуальная                           |

Для desktop-сборок (Linux/macOS/Windows) и мобильных платформ нужны дополнительные SDK — см. ниже.

## Установка — Backend

### 1. PostgreSQL

**Вариант A — Docker (самый быстрый, подходит для Linux/macOS/Windows одинаково):**

```bash
docker run -d --name university-postgres \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=university \
  -p 5432:5432 \
  -v university-pgdata:/var/lib/postgresql/data \
  postgres:16
```

Если у вас в репозитории уже есть свой `docker-compose.yml` для Postgres — используйте `docker compose up -d postgres`, команда выше просто не требует наличия compose-файла.

**Вариант B — нативная установка:**

- **Ubuntu / Debian:**
  ```bash
  sudo apt update
  sudo apt install postgresql postgresql-contrib
  sudo systemctl enable --now postgresql
  sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'postgres';"
  sudo -u postgres createdb university
  ```
- **Fedora / Arch:** `sudo dnf install postgresql-server` / `sudo pacman -S postgresql`, затем `initdb`, `systemctl enable --now postgresql`, далее аналогично создать пользователя/БД.
- **macOS (Homebrew):**
  ```bash
  brew install postgresql@16
  brew services start postgresql@16
  createuser -s postgres
  createdb -O postgres university
  ```
- **Windows:** скачайте установщик с [postgresql.org/download/windows](https://www.postgresql.org/download/windows/) (или `choco install postgresql`), при установке задайте пароль `postgres` для суперпользователя `postgres` и создайте базу `university` через pgAdmin или `psql`.

### 2. Python-окружение

**Linux / macOS:**

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
```

**Windows (PowerShell):**

```powershell
cd backend
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
copy .env.example .env
```

**Windows (cmd.exe):**

```cmd
cd backend
python -m venv .venv
.venv\Scripts\activate.bat
pip install -r requirements.txt
copy .env.example .env
```

### 3. Переменные окружения (`backend/.env`)

```env
DATABASE_URL=postgresql+psycopg://postgres:postgres@localhost:5432/university
SECRET_KEY=change-me-in-production
ACCESS_TOKEN_EXPIRE_MINUTES=1440
BACKEND_CORS_ORIGINS=["http://localhost:3000","http://localhost:8080"]
BACKEND_CORS_ORIGIN_REGEX='https?://(localhost|127\.0\.0\.1)(:\d+)?'
```

`BACKEND_CORS_ORIGIN_REGEX` уже покрывает `localhost`/`127.0.0.1` с любым портом — это важно, потому что `flutter run -d chrome` каждый раз поднимает дев-сервер на случайном порту. CORS вообще касается только Web-сборки: для Android/iOS/Windows/macOS/Linux-клиента (нативный HTTP-запрос через `dio`) CORS не применяется.

В проде обязательно смените `SECRET_KEY` на случайную строку (например, `openssl rand -hex 32`).

### 4. Миграции базы данных

```bash
alembic upgrade head
```

Применит всю цепочку `0001_initial_schema → 0006_add_guest_role` (создание таблиц факультетов/групп/студентов/расписания/посещаемости/успеваемости, refresh-токены, права пользователей, роль Guest).

### 5. Заполнение данными

```bash
python seed.py
```

⚠️ **Важно:** `seed.py` ожидает файл `dbb_plain.sql` (plain-SQL дамп) в корне репозитория, на уровень выше `backend/` — то есть рядом с `pubspec.yaml`. Скрипт **полностью пересоздаёт схему `public`** (`DROP SCHEMA public CASCADE`) и заливает данные из этого дампа, поэтому:

- Если дамп у вас есть — положите `dbb_plain.sql` в корень проекта перед запуском.
- Если дампа нет, `seed.py` упадёт с `FileNotFoundError`. В этом случае после `alembic upgrade head` создайте администратора вручную, например через короткий скрипт:

  ```python
  # backend/create_admin.py
  from app.core.security import get_password_hash
  from app.db.session import SessionLocal
  from app.models import User

  db = SessionLocal()
  db.add(User(username="admin", hashed_password=get_password_hash("admin123"), role="Admin"))
  db.commit()
  ```

  ```bash
  python create_admin.py
  ```

  Дальше можно создавать преподавателей/студентов и наполнять справочники через UI под этим админом.

### 6. Запуск API

```bash
uvicorn app.main:app --reload
```

Чтобы API был доступен с других устройств в локальной сети (например, для тестирования с физического телефона или эмулятора), запускайте с привязкой ко всем интерфейсам:

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

- API: `http://127.0.0.1:8000/api`
- Swagger UI: `http://127.0.0.1:8000/docs`
- Health-check: `http://127.0.0.1:8000/health`

## Установка — Flutter-клиент

### Установка Flutter SDK

**Linux:**

```bash
sudo apt update
sudo apt install curl git unzip xz-utils zip libglu1-mesa
cd ~
git clone https://github.com/flutter/flutter.git -b stable
echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc
source ~/.bashrc
flutter doctor
```

(альтернативно — `sudo snap install flutter --classic`)

**macOS:**

```bash
brew install --cask flutter
flutter doctor
```

Для сборки под iOS дополнительно нужен Xcode (из App Store) и CocoaPods: `sudo gem install cocoapods`.

**Windows:**

1. Скачайте zip с [docs.flutter.dev/get-started/install/windows](https://docs.flutter.dev/get-started/install/windows), распакуйте, например, в `C:\src\flutter`.
2. Добавьте `C:\src\flutter\bin` в переменную окружения `PATH`.
3. Проверьте:
   ```powershell
   flutter doctor
   ```

`flutter doctor` подскажет, чего не хватает (Android SDK / Xcode / Visual Studio / Chrome) — доустановите по его рекомендациям.

### Поддержка desktop-таргетов

В современных версиях Flutter desktop-платформы включены по умолчанию, но если `flutter devices` их не показывает — включите явно:

```bash
flutter config --enable-linux-desktop
flutter config --enable-macos-desktop
flutter config --enable-windows-desktop
```

Для сборки под **Linux desktop** дополнительно нужны системные пакеты:

```bash
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
```

### Получение зависимостей проекта

```bash
flutter pub get
```

Если в проекте ещё нет нативных платформенных папок (`android/`, `ios/`, `windows/`, `macos/`, `linux/`, `web/`) — сгенерируйте их:

```bash
flutter create .
```

## Запуск на разных платформах

Backend-URL передаётся через `--dart-define=API_URL=...` (по умолчанию `http://127.0.0.1:8000/api`).

```bash
# Web (Chrome)
flutter run -d chrome --dart-define=API_URL=http://127.0.0.1:8000/api

# Linux desktop
flutter run -d linux --dart-define=API_URL=http://127.0.0.1:8000/api

# macOS desktop
flutter run -d macos --dart-define=API_URL=http://127.0.0.1:8000/api

# Windows desktop
flutter run -d windows --dart-define=API_URL=http://127.0.0.1:8000/api
```

**Android-эмулятор** — `127.0.0.1` внутри эмулятора означает сам эмулятор, а не хост-машину, поэтому backend нужно адресовать через специальный alias `10.0.2.2`:

```bash
flutter run -d emulator-5554 --dart-define=API_URL=http://10.0.2.2:8000/api
```

**Физическое устройство (Android/iOS)** в той же Wi-Fi сети — используйте IP-адрес машины с backend (узнать: `ip a` на Linux/macOS, `ipconfig` на Windows) и не забудьте запустить uvicorn с `--host 0.0.0.0`:

```bash
flutter run -d <device-id> --dart-define=API_URL=http://192.168.1.50:8000/api
```

**iOS-симулятор** — может обращаться к `127.0.0.1` хост-машины напрямую, как desktop:

```bash
flutter run -d "iPhone 15" --dart-define=API_URL=http://127.0.0.1:8000/api
```

## Сборка релизов

```bash
# Web
flutter build web --dart-define=API_URL=https://api.example.com/api

# Android (APK)
flutter build apk --release --dart-define=API_URL=https://api.example.com/api

# Android (App Bundle для Google Play)
flutter build appbundle --release --dart-define=API_URL=https://api.example.com/api

# iOS (требует macOS + Xcode)
flutter build ios --release --dart-define=API_URL=https://api.example.com/api

# Linux
flutter build linux --release --dart-define=API_URL=https://api.example.com/api

# macOS
flutter build macos --release --dart-define=API_URL=https://api.example.com/api

# Windows
flutter build windows --release --dart-define=API_URL=https://api.example.com/api
```

## REST API

Базовый префикс: `/api`. Для каждой справочной сущности реализован единый набор CRUD-маршрутов:

```text
GET    /api/<entity>/list
GET    /api/<entity>/{id}
POST   /api/<entity>
PUT    /api/<entity>/{id}
DELETE /api/<entity>/{id}
```

Сущности:

```text
faculties, specialities, classrooms, subjects, groups, teachers, students,
disciplines, study-weeks, attendance, performance, execution, schedule
```

Аутентификация и права:

```text
POST /api/auth/login
POST /api/auth/guest
POST /api/auth/refresh
POST /api/auth/change-password
GET  /api/me
GET  /api/permissions/me
GET  /api/permissions/user/{userId}
```

Дополнительные эндпоинты:

```text
GET  /api/dashboard
GET  /api/schedule/group/{group_id}
GET  /api/schedule/teacher/{teacher_id}
GET  /api/students/{id}/attendance
GET  /api/students/{id}/performance
GET  /api/statistics/faculty/{faculty_id}
POST /api/attendance/bulk
```

Полная интерактивная документация — Swagger UI на `/docs`.

## Учётные записи

- Гостевой вход доступен прямо с экрана логина (кнопка «Войти как гость») — отдельные креды не нужны, аккаунт `guest` создаётся backend'ом автоматически при первом обращении к `/api/auth/guest`.
- Учётные записи Admin/Teacher/Student приходят из дампа `dbb_plain.sql` (см. [«Заполнение данными»](#5-заполнение-данными)) — фактические логины/пароли смотрите в самом дампе или у того, кто его готовил. Если вы стартуете с пустой базы без дампа, создайте администратора вручную способом, описанным выше, а остальных пользователей заводите через раздел «Пользователи» в UI под этим админом.

## Частые проблемы

- **`flutter pub get` ругается на версию SDK** — `pubspec.yaml` требует Dart `^3.9.2`. Обновите Flutter (`flutter upgrade`) или переключитесь на нужную версию через [FVM](https://fvm.app/).
- **Web-клиент не видит backend / ошибки CORS** — проверьте, что backend запущен и `BACKEND_CORS_ORIGIN_REGEX` покрывает адрес, с которого открыт Flutter Web (по умолчанию покрывает `localhost`/`127.0.0.1` с любым портом).
- **Android-эмулятор: `Connection refused`** — используйте `10.0.2.2` вместо `127.0.0.1` в `API_URL` (см. раздел про запуск).
- **`alembic upgrade head` падает на "multiple heads"** — в этом репозитории миграции линейны (`0001 → 0006`), такое возможно только если вы добавили свою миграцию параллельно чужой; проверьте `down_revision` у новых файлов.
- **Предупреждение от passlib про bcrypt при старте** — `requirements.txt` намеренно фиксирует `bcrypt<4.1`, потому что `passlib==1.7.4` несовместим с более новым bcrypt (читает удалённый атрибут версии). Не обновляйте bcrypt отдельно от passlib.
- **`seed.py: FileNotFoundError: dbb_plain.sql`** — см. раздел [«Заполнение данными»](#5-заполнение-данными): либо положите дамп в корень репозитория, либо создайте администратора вручную и наполняйте базу через UI.

## Проверки

```bash
# Backend
cd backend
python -m compileall app

# Frontend
flutter analyze
flutter test
```