# University Process Management System

Полноценная учебная ERP-система: Flutter 3.x клиент с Material 3 и FastAPI backend поверх PostgreSQL.

## Архитектура

```text
Flutter -> REST API -> FastAPI -> PostgreSQL
```

Прямого подключения Flutter к PostgreSQL нет. Клиент работает только через REST API и JWT.

## Структура

```text
backend/
  alembic/
    versions/0001_initial_schema.py
  app/
    api/          # auth, CRUD routes, extra API
    core/         # settings, JWT/password utilities
    db/           # SQLAlchemy base/session
    models/       # SQLAlchemy 2.0 models
    schemas/      # Pydantic schemas
    services/     # CRUD service
  seed.py
  requirements.txt
lib/
  core/
  models/
  services/
  providers/
  screens/
  widgets/
  routes/
```

## Backend

### 1. PostgreSQL

```bash
docker compose up -d postgres
```

### 2. Python environment

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env
```

### 3. Migrations and seed

```bash
alembic upgrade head
python seed.py
```

Seed создаёт минимум 5 записей в учебных таблицах и пользователей:

```text
admin / admin123
teacher / teacher123
```

### 4. Run API

```bash
uvicorn app.main:app --reload
```

API будет доступен на `http://127.0.0.1:8000`, Swagger UI: `http://127.0.0.1:8000/docs`.

## REST API

Для каждой сущности реализованы:

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

Дополнительные endpoints:

```text
POST /api/auth/login
GET  /api/dashboard
GET  /api/schedule/group/{group_id}
GET  /api/schedule/teacher/{teacher_id}
GET  /api/students/{id}/attendance
GET  /api/students/{id}/performance
GET  /api/statistics/faculty/{faculty_id}
POST /api/attendance/bulk
```

## Flutter

```bash
flutter pub get
flutter run -d chrome --dart-define=API_URL=http://127.0.0.1:8000/api
```

Клиент содержит:

- Login/Logout с JWT.
- Drawer-навигацию.
- Dashboard с количеством студентов, преподавателей, групп и факультетов.
- CRUD-экраны с DataTable2, SearchBar, сортировкой, dialog forms, loading/error/empty states.
- Расписание с фильтрами по группе, преподавателю и неделе.
- Посещаемость с выбором группы, даты, пары и bulk-сохранением.
- Успеваемость с выбором студента, дисциплины, преподавателя и оценки.

## Роли

```text
Admin   - полный CRUD-доступ
Teacher - расписание, посещаемость, успеваемость и просмотр нужных данных
```

## Проверки

В проекте выполнены:

```bash
python -m compileall backend
flutter analyze
flutter test
```
