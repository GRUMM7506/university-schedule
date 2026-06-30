from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import distinct, func, select
from sqlalchemy.orm import Session

from app.api.crud_router import build_crud_router
from app.api.deps import get_current_user, require_admin, require_any, require_staff
from app.core.security import create_access_token, get_password_hash, verify_password
from app.db.session import get_db
from app.models import (
    Attendance,
    Classroom,
    DisciplineLoad,
    Execution,
    Faculty,
    Performance,
    Schedule,
    Speciality,
    Student,
    StudentGroup,
    StudyWeek,
    Subject,
    Teacher,
    User,
    UserPermission,
)
from app.schemas import (
    AttendanceBulkItem,
    AttendanceCreate,
    AttendanceRead,
    AttendanceUpdate,
    ClassroomCreate,
    ClassroomRead,
    ClassroomUpdate,
    DashboardStats,
    DisciplineLoadCreate,
    DisciplineLoadRead,
    DisciplineLoadUpdate,
    ExecutionCreate,
    ExecutionRead,
    ExecutionUpdate,
    FacultyCreate,
    FacultyRead,
    FacultyStatistics,
    FacultyUpdate,
    LoginRequest,
    PerformanceCreate,
    PerformanceRead,
    PerformanceUpdate,
    RegisterStudent,
    ScheduleCreate,
    ScheduleRead,
    ScheduleUpdate,
    ScheduleView,
    SpecialityCreate,
    SpecialityRead,
    SpecialityUpdate,
    StudentCreate,
    StudentGroupCreate,
    StudentGroupRead,
    StudentGroupUpdate,
    StudentImportRow,
    StudentRead,
    StudentUpdate,
    StudyWeekCreate,
    StudyWeekRead,
    StudyWeekUpdate,
    SubjectCreate,
    SubjectRead,
    SubjectUpdate,
    TeacherCreate,
    TeacherImportRow,
    TeacherRead,
    TeacherUpdate,
    TemplateResponse,
    Token,
)
from app.services.crud import CRUDService
from app.models.permissions import ALL_PERMISSIONS, DEFAULT_ROLE_PERMISSIONS, PERMISSION_LABELS
from pydantic import BaseModel

api_router = APIRouter(prefix="/api")


# ─── Auth ─────────────────────────────────────────────────────────────────────

def _student_for_user(db: Session, user: User) -> Student | None:
    student = db.scalar(select(Student).where(Student.user_id == user.id))
    if student:
        return student

    email_candidates = [f"{user.username}@msu.ru", f"{user.username}@student.uz"]
    if "@" in user.username:
        email_candidates.append(user.username)
    return db.scalar(select(Student).where(Student.email.in_(email_candidates)))


@api_router.post("/auth/login", response_model=Token)
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(User.username == payload.username))
    if user is None or not verify_password(payload.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid username or password")
    
    from app.core.security import create_refresh_token
    refresh_token = create_refresh_token(user.username)
    user.refresh_token = refresh_token
    db.commit()

    # Attach student_id if user is a student
    student_id = None
    if user.role == "Student":
        student = _student_for_user(db, user)
        if student:
            student_id = student.id
    return Token(
        access_token=create_access_token(user.username, user.role),
        role=user.role,
        username=user.username,
        student_id=student_id,
    )

@api_router.post("/auth/refresh", response_model=Token)
def refresh_token(payload: dict, db: Session = Depends(get_db)):
    from app.core.security import create_refresh_token
    refresh_token = payload.get("refresh_token")
    if not refresh_token:
        raise HTTPException(status_code=400, detail="Refresh token is missing")
    
    try:
        from jose import jwt
        from app.core.config import settings
        payload_data = jwt.decode(refresh_token, settings.secret_key, algorithms=[settings.algorithm])
        username = payload_data.get("sub")
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    user = db.scalar(select(User).where(User.username == username))
    if user is None:
        raise HTTPException(status_code=401, detail="User not found")

    new_refresh = create_refresh_token(user.username)
    user.refresh_token = new_refresh
    db.commit()

    student_id = None
    if user.role == "Student":
        student = _student_for_user(db, user)
        if student:
            student_id = student.id

    return Token(
        access_token=create_access_token(user.username, user.role),
        role=user.role,
        username=user.username,
        student_id=student_id,
    )

@api_router.post("/auth/guest", response_model=Token)
def guest_login(db: Session = Depends(get_db)):
    # Find existing guest user or create one
    guest = db.scalar(select(User).where(User.username == "guest"))
    if guest is None:
        guest = User(
            username="guest",
            hashed_password=get_password_hash("guest"),
            role="Guest",
        )
        db.add(guest)
        db.commit()
        db.refresh(guest)
    return Token(
        access_token=create_access_token(guest.username, guest.role),
        role=guest.role,
        username=guest.username,
        student_id=None,
    )

@api_router.post("/auth/change-password")
def change_password(payload: dict, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    old_password = payload.get("old_password")
    new_password = payload.get("new_password")
    if not old_password or not new_password:
        raise HTTPException(status_code=400, detail="Both old and new passwords are required")
    
    if not verify_password(old_password, user.hashed_password):
        raise HTTPException(status_code=400, detail="Old password is incorrect")
    
    user.hashed_password = get_password_hash(new_password)
    db.commit()
    return {"ok": True}

@api_router.get("/me")
def me(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Return current user info with role-specific linked entity."""
    result = {"id": user.id, "username": user.username, "role": user.role}
    if user.role == "Student":
        student = _student_for_user(db, user)
        if student:
            result["linked_id"] = student.id
            result["fio"] = student.fio
    elif user.role == "Teacher":
        teacher = db.scalar(select(Teacher).where(Teacher.user_id == user.id))
        if not teacher:
            teacher = db.scalar(select(Teacher).where(Teacher.email == f"{user.username}@uni.uz"))
        if teacher:
            result["linked_id"] = teacher.id
            result["fio"] = teacher.fio
    elif user.role == "Guest":
        result["fio"] = user.username
    return result


# ─── Dashboard ────────────────────────────────────────────────────────────────
@api_router.get("/dashboard", response_model=DashboardStats, dependencies=[Depends(require_staff)])
def dashboard(db: Session = Depends(get_db)):
    return DashboardStats(
        students=db.scalar(select(func.count(Student.id))) or 0,
        teachers=db.scalar(select(func.count(Teacher.id))) or 0,
        groups=db.scalar(select(func.count(StudentGroup.id))) or 0,
        faculties=db.scalar(select(func.count(Faculty.id))) or 0,
    )


@api_router.get("/dashboard/student/{student_id}", dependencies=[Depends(require_any)])
def student_dashboard(student_id: int, db: Session = Depends(get_db)):
    student = db.scalar(select(Student).where(Student.id == student_id))
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    attendance_total = db.scalar(select(func.count(Attendance.id)).where(Attendance.student_id == student_id)) or 0
    attendance_present = db.scalar(
        select(func.count(Attendance.id)).where(Attendance.student_id == student_id, Attendance.mark == 2)
    ) or 0
    avg_mark_row = db.scalar(
        select(func.avg(Performance.mark)).where(Performance.student_id == student_id)
    )
    avg_mark = round(float(avg_mark_row), 2) if avg_mark_row else 0.0
    grades_count = db.scalar(select(func.count(Performance.id)).where(Performance.student_id == student_id)) or 0
    return {
        "fio": student.fio,
        "group_id": student.group_id,
        "attendance_total": attendance_total,
        "attendance_present": attendance_present,
        "attendance_rate": round(attendance_present / attendance_total * 100, 1) if attendance_total > 0 else 0,
        "avg_mark": avg_mark,
        "grades_count": grades_count,
    }


@api_router.get("/dashboard/teacher/{teacher_id}", dependencies=[Depends(require_any)])
def teacher_dashboard(teacher_id: int, db: Session = Depends(get_db)):
    teacher = db.scalar(select(Teacher).where(Teacher.id == teacher_id))
    if not teacher:
        raise HTTPException(status_code=404, detail="Teacher not found")
    disciplines_count = db.scalar(
        select(func.count(DisciplineLoad.id)).where(DisciplineLoad.teacher_id == teacher_id)
    ) or 0
    groups_ids = db.scalars(
        select(distinct(DisciplineLoad.group_id)).where(DisciplineLoad.teacher_id == teacher_id)
    ).all()
    students_count = db.scalar(
        select(func.count(Student.id)).where(Student.group_id.in_(groups_ids))
    ) or 0
    schedule_count = db.scalar(
        select(func.count(Schedule.id)).where(Schedule.teacher_id == teacher_id)
    ) or 0
    return {
        "fio": teacher.fio,
        "position": teacher.position,
        "disciplines_count": disciplines_count,
        "groups_count": len(groups_ids),
        "students_count": students_count,
        "schedule_count": schedule_count,
    }


# ─── CRUD Entities ─────────────────────────────────────────────────────────────

entities = [
    ("faculties", Faculty, FacultyCreate, FacultyUpdate, FacultyRead, False, True),
    ("specialities", Speciality, SpecialityCreate, SpecialityUpdate, SpecialityRead, False, True),
    ("classrooms", Classroom, ClassroomCreate, ClassroomUpdate, ClassroomRead, False, True),
    ("subjects", Subject, SubjectCreate, SubjectUpdate, SubjectRead, False, True),
    ("groups", StudentGroup, StudentGroupCreate, StudentGroupUpdate, StudentGroupRead, False, True),
    ("teachers", Teacher, TeacherCreate, TeacherUpdate, TeacherRead, False, True),
    ("students", Student, StudentCreate, StudentUpdate, StudentRead, False, True),
    ("disciplines", DisciplineLoad, DisciplineLoadCreate, DisciplineLoadUpdate, DisciplineLoadRead, False, True),
    ("study-weeks", StudyWeek, StudyWeekCreate, StudyWeekUpdate, StudyWeekRead, False, True),
    ("attendance", Attendance, AttendanceCreate, AttendanceUpdate, AttendanceRead, True, False),
    ("performance", Performance, PerformanceCreate, PerformanceUpdate, PerformanceRead, True, False),
    ("execution", Execution, ExecutionCreate, ExecutionUpdate, ExecutionRead, True, False),
    ("schedule", Schedule, ScheduleCreate, ScheduleUpdate, ScheduleRead, True, False),
]

for prefix, model, create_schema, update_schema, read_schema, staff_read, any_read in entities:
    api_router.include_router(
        build_crud_router(
            model=model,
            create_schema=create_schema,
            update_schema=update_schema,
            read_schema=read_schema,
            staff_read=staff_read,
            any_read=any_read,
        ),
        prefix=f"/{prefix}",
        tags=[prefix],
    )


# ─── User Management (Admin only) ─────────────────────────────────────────────

class UserRead(BaseModel):
    id: int
    username: str
    role: str

    class Config:
        from_attributes = True


class UserCreate(BaseModel):
    username: str
    password: str
    role: str


class UserUpdate(BaseModel):
    password: str | None = None
    role: str | None = None


class ProfileSetupPayload(BaseModel):
    fio: str
    group_id: int | None = None
    birth_date: date | None = None
    position: str | None = None


@api_router.post("/profile/setup", dependencies=[Depends(require_any)])
def setup_profile(
    payload: ProfileSetupPayload,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if user.role == "Admin":
        raise HTTPException(status_code=400, detail="Администратору профиль не требуется")

    if user.role == "Student":
        if payload.group_id is None or payload.birth_date is None:
            raise HTTPException(status_code=400, detail="Укажите группу и дату рождения")
        email = f"{user.username}@msu.ru"
        existing = db.scalar(select(Student).where(Student.email == email))
        if existing:
            return {"linked_id": existing.id}
        entity = Student(
            fio=payload.fio,
            group_id=payload.group_id,
            email=email,
            birth_date=payload.birth_date,
        )
    elif user.role == "Teacher":
        if not payload.position:
            raise HTTPException(status_code=400, detail="Укажите должность")
        email = f"{user.username}@uni.uz"
        existing = db.scalar(select(Teacher).where(Teacher.email == email))
        if existing:
            return {"linked_id": existing.id}
        entity = Teacher(
            fio=payload.fio,
            position=payload.position,
            email=email,
        )
    else:
        raise HTTPException(status_code=400, detail="Неизвестная роль пользователя")

    db.add(entity)
    db.commit()
    db.refresh(entity)
    return {"linked_id": entity.id}


class ProfileUpdatePayload(BaseModel):
    fio: str | None = None
    position: str | None = None
    group_id: int | None = None
    birth_date: date | None = None
    phone: str | None = None
    address: str | None = None


@api_router.put("/profile/update", dependencies=[Depends(require_any)])
def update_profile(
    payload: ProfileUpdatePayload,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Update the current user's linked student or teacher profile."""
    if user.role == "Admin":
        raise HTTPException(status_code=400, detail="Администратору профиль не требуется")

    if user.role == "Student":
        entity = _student_for_user(db, user)
        if not entity:
            raise HTTPException(status_code=404, detail="Профиль студента не найден")
        if payload.fio is not None:
            entity.fio = payload.fio
        if payload.group_id is not None:
            entity.group_id = payload.group_id
        if payload.birth_date is not None:
            entity.birth_date = payload.birth_date
        if payload.phone is not None:
            entity.phone = payload.phone
        if payload.address is not None:
            entity.address = payload.address

    elif user.role == "Teacher":
        entity = db.scalar(select(Teacher).where(Teacher.email == f"{user.username}@uni.uz"))
        if not entity:
            raise HTTPException(status_code=404, detail="Профиль преподавателя не найден")
        if payload.fio is not None:
            entity.fio = payload.fio
        if payload.position is not None:
            entity.position = payload.position
        if payload.phone is not None:
            entity.phone = payload.phone
        if payload.address is not None:
            entity.address = payload.address
    else:
        raise HTTPException(status_code=400, detail="Неизвестная роль")

    db.commit()
    return {"ok": True}


@api_router.get("/users", response_model=list[UserRead], dependencies=[Depends(require_admin)])
def list_users(db: Session = Depends(get_db)):
    return db.scalars(select(User).order_by(User.id)).all()


@api_router.post("/users", response_model=UserRead, dependencies=[Depends(require_admin)])
def create_user(payload: UserCreate, db: Session = Depends(get_db)):
    existing = db.scalar(select(User).where(User.username == payload.username))
    if existing:
        raise HTTPException(status_code=400, detail="Username already exists")
    user = User(username=payload.username, hashed_password=get_password_hash(payload.password), role=payload.role)
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@api_router.put("/users/{user_id}", response_model=UserRead, dependencies=[Depends(require_admin)])
def update_user(user_id: int, payload: UserUpdate, db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(User.id == user_id))
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if payload.password:
        user.hashed_password = get_password_hash(payload.password)
    if payload.role:
        user.role = payload.role
    db.commit()
    db.refresh(user)
    return user


@api_router.delete("/users/{user_id}", dependencies=[Depends(require_admin)])
def delete_user(user_id: int, db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(User.id == user_id))
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    db.delete(user)
    db.commit()
    return {"ok": True}


# ─── Schedule Views ────────────────────────────────────────────────────────────

def schedule_view_stmt():
    return (
        select(
            Schedule.id,
            Schedule.day_num,
            Schedule.pair_num,
            Subject.name.label("subject"),
            Schedule.subject_id,
            Teacher.fio.label("teacher"),
            Schedule.teacher_id,
            Classroom.number.label("classroom"),
            Schedule.classroom_id,
            Schedule.lesson_type,
            StudentGroup.name.label("group"),
            Schedule.group_id,
            StudyWeek.name.label("week"),
            Schedule.study_week_id,
        )
        .join(Subject, Subject.id == Schedule.subject_id)
        .join(Teacher, Teacher.id == Schedule.teacher_id)
        .join(Classroom, Classroom.id == Schedule.classroom_id)
        .join(StudentGroup, StudentGroup.id == Schedule.group_id)
        .join(StudyWeek, StudyWeek.id == Schedule.study_week_id)
        .order_by(Schedule.day_num, Schedule.pair_num)
    )


@api_router.get("/schedule/group/{group_id}", response_model=list[ScheduleView], dependencies=[Depends(require_any)])
def group_schedule(group_id: int, week_id: int | None = None, db: Session = Depends(get_db)):
    stmt = schedule_view_stmt().where(Schedule.group_id == group_id)
    if week_id:
        stmt = stmt.where(Schedule.study_week_id == week_id)
    return [ScheduleView(**row._asdict()) for row in db.execute(stmt).all()]


@api_router.get("/schedule/teacher/{teacher_id}", response_model=list[ScheduleView], dependencies=[Depends(require_any)])
def teacher_schedule(teacher_id: int, week_id: int | None = None, db: Session = Depends(get_db)):
    stmt = schedule_view_stmt().where(Schedule.teacher_id == teacher_id)
    if week_id:
        stmt = stmt.where(Schedule.study_week_id == week_id)
    return [ScheduleView(**row._asdict()) for row in db.execute(stmt).all()]

# ─── Permissions ──────────────────────────────────────────────────────────────────

@api_router.get("/permissions/me")
def get_my_permissions(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Flat list of permissions effectively granted to the current user
    (role defaults with individual overrides applied). Admin always gets
    everything. Used by the Flutter app to drive menu/UI visibility."""
    if user.role == "Admin":
        return {"permissions": list(ALL_PERMISSIONS)}

    role_defaults = DEFAULT_ROLE_PERMISSIONS.get(user.role, set())
    overrides = {
        p.permission: p.is_granted
        for p in db.scalars(select(UserPermission).where(UserPermission.user_id == user.id)).all()
    }
    effective = {
        perm for perm in ALL_PERMISSIONS
        if overrides.get(perm, perm in role_defaults)
    }
    return {"permissions": sorted(effective)}

@api_router.get("/permissions/user/{userId}")
def get_user_permissions(userId: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    # Only Admin can view other's permissions, others can view their own
    if user.role != "Admin" and user.id != userId:
        raise HTTPException(status_code=403, detail="Not enough permissions")

    target = db.scalar(select(User).where(User.id == userId))
    if target is None:
        raise HTTPException(status_code=404, detail="User not found")

    overrides = {
        p.permission: p.is_granted
        for p in db.scalars(select(UserPermission).where(UserPermission.user_id == userId)).all()
    }
    role_defaults = DEFAULT_ROLE_PERMISSIONS.get(target.role, set())

    permissions = [
        {
            "permission": perm,
            "label": PERMISSION_LABELS.get(perm, perm),
            "default_granted": perm in role_defaults,
            "override": overrides.get(perm),
        }
        for perm in ALL_PERMISSIONS
    ]
    return {"permissions": permissions}


@api_router.put("/permissions/{userId}")
def update_user_permission(userId: int, payload: dict, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if user.role != "Admin":
        raise HTTPException(status_code=403, detail="Only administrators can manage permissions")

    permission = payload.get("permission")
    is_granted = payload.get("is_granted")

    if userId is None or not permission:
        raise HTTPException(status_code=400, detail="userId and permission are required")
    if permission not in ALL_PERMISSIONS:
        raise HTTPException(status_code=400, detail="Unknown permission")

    target = db.scalar(select(User).where(User.id == userId))
    if target is None:
        raise HTTPException(status_code=404, detail="User not found")

    perm = db.scalar(select(UserPermission).where(
        UserPermission.user_id == userId,
        UserPermission.permission == permission,
    ))

    if is_granted is None:
        # Reset to role default: drop the override row if present.
        if perm:
            db.delete(perm)
    elif perm:
        perm.is_granted = is_granted
    else:
        perm = UserPermission(user_id=userId, permission=permission, is_granted=is_granted)
        db.add(perm)

    db.commit()
    return {"ok": True}



@api_router.get("/schedule/student/{student_id}", response_model=list[ScheduleView], dependencies=[Depends(require_any)])
def student_schedule(student_id: int, week_id: int | None = None, db: Session = Depends(get_db)):
    student = db.scalar(select(Student).where(Student.id == student_id))
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    stmt = schedule_view_stmt().where(Schedule.group_id == student.group_id)
    if week_id:
        stmt = stmt.where(Schedule.study_week_id == week_id)
    return [ScheduleView(**row._asdict()) for row in db.execute(stmt).all()]


# ─── Student Detail Endpoints ──────────────────────────────────────────────────

@api_router.get("/students/{student_id}/attendance", response_model=list[AttendanceRead], dependencies=[Depends(require_any)])
def student_attendance(student_id: int, db: Session = Depends(get_db)):
    return db.scalars(select(Attendance).where(Attendance.student_id == student_id).order_by(Attendance.day_date.desc())).all()


@api_router.get("/students/{student_id}/performance", response_model=list[PerformanceRead], dependencies=[Depends(require_any)])
def student_performance(student_id: int, db: Session = Depends(get_db)):
    return db.scalars(select(Performance).where(Performance.student_id == student_id).order_by(Performance.tour_num)).all()


# ─── Attendance Bulk ───────────────────────────────────────────────────────────

@api_router.post("/attendance/bulk", response_model=list[AttendanceRead], dependencies=[Depends(require_staff)])
def save_attendance_bulk(items: list[AttendanceBulkItem], db: Session = Depends(get_db)):
    service = CRUDService(Attendance)
    saved = []
    for item in items:
        existing = db.scalar(
            select(Attendance).where(
                Attendance.student_id == item.student_id,
                Attendance.day_date == item.day_date,
                Attendance.pair_num == item.pair_num,
            )
        )
        if existing:
            existing.mark = item.mark
            saved.append(existing)
        else:
            saved.append(Attendance(**item.model_dump()))
            db.add(saved[-1])
    service._commit(db)
    return saved


# ─── Gradebook ────────────────────────────────────────────────────────────────

@api_router.get("/gradebook", dependencies=[Depends(require_staff)])
def gradebook(group_id: int | None = None, discipline_id: int | None = None, db: Session = Depends(get_db)):
    """Returns gradebook: list of students with their performance marks."""
    query = (
        select(
            Student.id.label("student_id"),
            Student.fio.label("student_fio"),
            StudentGroup.name.label("group_name"),
            Performance.id.label("perf_id"),
            Performance.discipline_id,
            Performance.mark,
            Performance.control_type,
            Performance.tour_num,
            Subject.name.label("subject_name"),
        )
        .join(StudentGroup, StudentGroup.id == Student.group_id)
        .outerjoin(Performance, Performance.student_id == Student.id)
        .outerjoin(DisciplineLoad, DisciplineLoad.id == Performance.discipline_id)
        .outerjoin(Subject, Subject.id == DisciplineLoad.subject_id)
    )
    if group_id:
        query = query.where(Student.group_id == group_id)
    if discipline_id:
        query = query.where(Performance.discipline_id == discipline_id)
    query = query.order_by(Student.fio, Performance.discipline_id)
    rows = db.execute(query).all()
    return [dict(row._asdict()) for row in rows]


# ─── Statistics ───────────────────────────────────────────────────────────────

@api_router.get("/statistics/faculty/{faculty_id}", response_model=FacultyStatistics, dependencies=[Depends(require_staff)])
def faculty_statistics(faculty_id: int, db: Session = Depends(get_db)):
    groups_stmt = select(StudentGroup.id).join(Speciality).where(Speciality.faculty_id == faculty_id).subquery()
    students = db.scalar(select(func.count(Student.id)).where(Student.group_id.in_(select(groups_stmt.c.id)))) or 0
    groups = db.scalar(select(func.count()).select_from(groups_stmt)) or 0
    teachers = (
        db.scalar(
            select(func.count(distinct(DisciplineLoad.teacher_id))).where(
                DisciplineLoad.group_id.in_(select(groups_stmt.c.id))
            )
        )
        or 0
    )
    return FacultyStatistics(students_count=students, groups_count=groups, teachers_count=teachers)
