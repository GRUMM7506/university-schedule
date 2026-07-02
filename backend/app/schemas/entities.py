import re
from datetime import date
from typing import Any

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator, model_validator

_FIO_PATTERN = re.compile(r"^[A-Za-zА-Яа-яЁё\s\-]+$")
_PHONE_PATTERN = re.compile(r"^\+?[0-9\s\-()]+$")


def _validate_fio(value: str | None) -> str | None:
    if value is None:
        return value
    if not _FIO_PATTERN.match(value):
        raise ValueError("ФИО должно содержать только буквы, пробелы и дефис")
    return value


def _validate_phone(value: str | None) -> str | None:
    if value is None or value == "":
        return value
    if not _PHONE_PATTERN.match(value):
        raise ValueError("Телефон должен содержать только цифры, пробелы, скобки, дефис и знак +")
    return value


class OrmModel(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class TemplateResponse(BaseModel):
    data: Any
    message: str | None = None
    status: str = "success"


class Token(BaseModel):
    access_token: str
    refresh_token: str | None = None
    token_type: str = "bearer"
    role: str
    username: str = ""
    student_id: int | None = None


class LoginRequest(BaseModel):
    username: str
    password: str


class UserRead(OrmModel):
    id: int
    username: str
    role: str


class FacultyBase(BaseModel):
    name: str = Field(min_length=2, max_length=160)


class FacultyCreate(FacultyBase):
    pass


class FacultyUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=160)


class FacultyRead(FacultyBase, OrmModel):
    id: int


class SpecialityBase(BaseModel):
    name: str = Field(min_length=2, max_length=160)
    faculty_id: int


class SpecialityCreate(SpecialityBase):
    pass


class SpecialityUpdate(BaseModel):
    name: str | None = None
    faculty_id: int | None = None


class SpecialityRead(SpecialityBase, OrmModel):
    id: int


class ClassroomBase(BaseModel):
    number: str
    type: str


class ClassroomCreate(ClassroomBase):
    pass


class ClassroomUpdate(BaseModel):
    number: str | None = None
    type: str | None = None


class ClassroomRead(ClassroomBase, OrmModel):
    id: int


class SubjectBase(BaseModel):
    name: str
    semester: int = Field(ge=1, le=12)
    hours: int = Field(gt=0)
    control_type: int = Field(ge=0, le=1)


class SubjectCreate(SubjectBase):
    pass


class SubjectUpdate(BaseModel):
    name: str | None = None
    semester: int | None = Field(default=None, ge=1, le=12)
    hours: int | None = Field(default=None, gt=0)
    control_type: int | None = Field(default=None, ge=0, le=1)


class SubjectRead(SubjectBase, OrmModel):
    id: int


class StudentGroupBase(BaseModel):
    name: str
    speciality_id: int
    course: int = Field(ge=1, le=6)


class StudentGroupCreate(StudentGroupBase):
    pass


class StudentGroupUpdate(BaseModel):
    name: str | None = None
    speciality_id: int | None = None
    course: int | None = Field(default=None, ge=1, le=6)


class StudentGroupRead(StudentGroupBase, OrmModel):
    id: int


class StudyWeekBase(BaseModel):
    name: str = Field(min_length=2, max_length=160)
    start_date: date
    end_date: date


class StudyWeekCreate(StudyWeekBase):
    pass


class StudyWeekUpdate(BaseModel):
    name: str | None = None
    start_date: date | None = None
    end_date: date | None = None


class StudyWeekRead(StudyWeekBase, OrmModel):
    id: int



class TeacherBase(BaseModel):
    fio: str
    scientific_degree: str | None = None
    academic_title: str | None = None
    position: str | None = None
    phone: str | None = None
    address: str | None = None
    email: EmailStr | None = None

    _v_fio = field_validator("fio")(_validate_fio)
    _v_phone = field_validator("phone")(_validate_phone)


class TeacherCreate(TeacherBase):
    pass


class TeacherUpdate(BaseModel):
    fio: str | None = None
    scientific_degree: str | None = None
    academic_title: str | None = None
    position: str | None = None
    phone: str | None = None
    address: str | None = None
    email: EmailStr | None = None

    _v_fio = field_validator("fio")(_validate_fio)
    _v_phone = field_validator("phone")(_validate_phone)


class TeacherRead(TeacherBase, OrmModel):
    id: int


class StudentBase(BaseModel):
    fio: str
    group_id: int
    phone: str | None = None
    address: str | None = None
    email: EmailStr | None = None
    birth_date: date

    _v_fio = field_validator("fio")(_validate_fio)
    _v_phone = field_validator("phone")(_validate_phone)


class StudentCreate(StudentBase):
    pass


class StudentUpdate(BaseModel):
    fio: str | None = None
    group_id: int | None = None
    phone: str | None = None
    address: str | None = None
    email: EmailStr | None = None
    birth_date: date | None = None

    _v_fio = field_validator("fio")(_validate_fio)
    _v_phone = field_validator("phone")(_validate_phone)


class StudentRead(StudentBase, OrmModel):
    id: int


class DisciplineLoadBase(BaseModel):
    subject_id: int
    teacher_id: int
    group_id: int
    semester: int = Field(ge=1, le=12)
    lecture_hours: int = Field(ge=0)
    practical_hours: int = Field(ge=0)
    lab_hours: int = Field(ge=0)
    other_hours: int = Field(ge=0)
    control_hours: int = Field(ge=0)


class DisciplineLoadCreate(DisciplineLoadBase):
    pass


class DisciplineLoadUpdate(BaseModel):
    subject_id: int | None = None
    teacher_id: int | None = None
    group_id: int | None = None
    semester: int | None = Field(default=None, ge=1, le=12)
    lecture_hours: int | None = Field(default=None, ge=0)
    practical_hours: int | None = Field(default=None, ge=0)
    lab_hours: int | None = Field(default=None, ge=0)
    other_hours: int | None = Field(default=None, ge=0)


class DisciplineLoadRead(DisciplineLoadBase, OrmModel):
    id: int


class AttendanceBase(BaseModel):
    student_id: int
    day_date: date
    pair_num: int = Field(ge=1, le=8)
    # A stored row is always an exception: 0 = отсутствовал, 1 = опоздал.
    # Presence is never stored — no row for a (student, day_date, pair_num)
    # means the student was simply there on time.
    mark: int = Field(ge=0, le=1)


class AttendanceCreate(AttendanceBase):
    pass


class AttendanceUpdate(BaseModel):
    student_id: int | None = None
    day_date: date | None = None
    pair_num: int | None = Field(default=None, ge=1, le=8)
    mark: int | None = Field(default=None, ge=0, le=1)


class AttendanceRead(AttendanceBase, OrmModel):
    id: int


class AttendanceBulkItem(BaseModel):
    student_id: int
    day_date: date
    pair_num: int = Field(ge=1, le=8)
    # None = present (the default) — clears any existing absent/late record
    # for this slot. 0 = отсутствовал, 1 = опоздал.
    mark: int | None = Field(default=None, ge=0, le=1)


def _validate_mark_for_control_type(control_type: int | None, mark: int | None) -> None:
    """Зачёт (0) only uses 0..3 — недопуск/неявка/не зачёт/зачёт.
    Экзамен (1) uses the full 0..5 scale."""
    if control_type is None or mark is None:
        return
    if control_type == 0 and not (0 <= mark <= 3):
        raise ValueError("Для зачёта оценка должна быть в диапазоне 0-3 (недопуск/неявка/не зачёт/зачёт)")
    if control_type == 1 and not (0 <= mark <= 5):
        raise ValueError("Для экзамена оценка должна быть в диапазоне 0-5")


class PerformanceBase(BaseModel):
    student_id: int
    discipline_id: int
    teacher_id: int
    control_type: int = Field(ge=0, le=1)
    tour_num: int = Field(ge=1, le=4)
    mark: int = Field(ge=0, le=5)

    @model_validator(mode="after")
    def _check_mark_range(self):
        _validate_mark_for_control_type(self.control_type, self.mark)
        return self


class PerformanceCreate(PerformanceBase):
    pass


class PerformanceUpdate(BaseModel):
    student_id: int | None = None
    discipline_id: int | None = None
    teacher_id: int | None = None
    control_type: int | None = Field(default=None, ge=0, le=1)
    tour_num: int | None = Field(default=None, ge=1, le=4)
    mark: int | None = Field(default=None, ge=0, le=5)

    @model_validator(mode="after")
    def _check_mark_range(self):
        _validate_mark_for_control_type(self.control_type, self.mark)
        return self


class PerformanceRead(PerformanceBase, OrmModel):
    id: int


class ExecutionBase(BaseModel):
    teacher_id: int
    discipline_id: int
    lectures: int = Field(ge=0)
    practicals: int = Field(ge=0)
    labs: int = Field(ge=0)
    other_works: int = Field(ge=0)


class ExecutionCreate(ExecutionBase):
    pass


class ExecutionUpdate(BaseModel):
    teacher_id: int | None = None
    discipline_id: int | None = None
    lectures: int | None = Field(default=None, ge=0)
    practicals: int | None = Field(default=None, ge=0)
    labs: int | None = Field(default=None, ge=0)
    other_works: int | None = Field(default=None, ge=0)


class ExecutionRead(ExecutionBase, OrmModel):
    id: int


class ScheduleBase(BaseModel):
    study_week_id: int
    day_num: int = Field(ge=1, le=6)
    pair_num: int = Field(ge=1, le=8)
    subject_id: int
    teacher_id: int
    lesson_type: int = Field(ge=0, le=3)
    classroom_id: int
    group_id: int


class ScheduleCreate(ScheduleBase):
    pass


class ScheduleUpdate(BaseModel):
    study_week_id: int | None = None
    day_num: int | None = Field(default=None, ge=1, le=6)
    pair_num: int | None = Field(default=None, ge=1, le=8)
    subject_id: int | None = None
    teacher_id: int | None = None
    lesson_type: int | None = Field(default=None, ge=0, le=3)
    classroom_id: int | None = None
    group_id: int | None = None


class ScheduleRead(ScheduleBase, OrmModel):
    id: int


class ScheduleView(BaseModel):
    id: int
    day_num: int
    pair_num: int
    subject: str
    subject_id: int
    teacher: str
    teacher_id: int
    classroom: str
    classroom_id: int
    lesson_type: int
    group: str
    group_id: int
    week: str
    study_week_id: int


class FacultyStatistics(BaseModel):
    students_count: int
    groups_count: int
    teachers_count: int


class DashboardStats(BaseModel):
    students: int
    teachers: int
    groups: int
    faculties: int


class BulkImportResult(BaseModel):
    success_count: int
    error_count: int
    errors: list[str] | None = None


class RegisterStudent(StudentCreate):
    password: str = Field(min_length=6)


class StudentImportRow(BaseModel):
    fio: str
    group_name: str
    email: EmailStr
    phone: str | None = None
    address: str | None = None
    birth_date: date


class TeacherImportRow(BaseModel):
    fio: str
    position: str
    email: EmailStr
    phone: str | None = None
    address: str | None = None


SchemaRegistry = dict[str, dict[str, Any]]
