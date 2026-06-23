from datetime import date, timedelta

from sqlalchemy import delete

from app.core.security import get_password_hash
from app.db.session import SessionLocal
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
)


def reset(db):
    for model in [
        Schedule,
        Execution,
        Performance,
        Attendance,
        DisciplineLoad,
        Student,
        StudentGroup,
        StudyWeek,
        Subject,
        Classroom,
        Teacher,
        Speciality,
        Faculty,
        User,
    ]:
        db.execute(delete(model))
    db.commit()


def main() -> None:
    db = SessionLocal()
    try:
        reset(db)

        faculties = [
            Faculty(name="Факультет информационных технологий"),
            Faculty(name="Экономический факультет"),
            Faculty(name="Факультет энергетики"),
            Faculty(name="Факультет педагогики"),
            Faculty(name="Юридический факультет"),
        ]
        db.add_all(faculties)
        db.flush()

        specialities = [
            Speciality(name="Программная инженерия", faculty_id=faculties[0].id),
            Speciality(name="Информационные системы", faculty_id=faculties[0].id),
            Speciality(name="Бухгалтерский учет", faculty_id=faculties[1].id),
            Speciality(name="Электроэнергетика", faculty_id=faculties[2].id),
            Speciality(name="Начальное образование", faculty_id=faculties[3].id),
        ]
        db.add_all(specialities)
        db.flush()

        classrooms = [
            Classroom(number="101", type="лк"),
            Classroom(number="202", type="кк"),
            Classroom(number="303", type="пк"),
            Classroom(number="404", type="лб"),
            Classroom(number="505", type="лк"),
        ]
        db.add_all(classrooms)

        teachers = [
            Teacher(fio="Каримов Азиз Рустамович", scientific_degree="PhD", academic_title="Доцент", position="Заведующий кафедрой", phone="+998901111111", email="karimov@uni.uz", address="Ташкент"),
            Teacher(fio="Ахмедова Дилноза Акмаловна", scientific_degree="DSc", academic_title="Профессор", position="Профессор", phone="+998902222222", email="ahmedova@uni.uz", address="Самарканд"),
            Teacher(fio="Юсупов Бахтиёр Нодирович", scientific_degree="PhD", academic_title="Доцент", position="Доцент", phone="+998903333333", email="yusupov@uni.uz", address="Бухара"),
            Teacher(fio="Саидова Малика Ильхомовна", scientific_degree=None, academic_title=None, position="Старший преподаватель", phone="+998904444444", email="saidova@uni.uz", address="Навои"),
            Teacher(fio="Назаров Тимур Алиевич", scientific_degree="PhD", academic_title="Доцент", position="Доцент", phone="+998905555555", email="nazarov@uni.uz", address="Андижан"),
        ]
        db.add_all(teachers)

        subjects = [
            Subject(name="Базы данных", semester=3, hours=120, control_type=1),
            Subject(name="Алгоритмы", semester=2, hours=110, control_type=1),
            Subject(name="Экономическая теория", semester=1, hours=90, control_type=0),
            Subject(name="Электротехника", semester=4, hours=100, control_type=1),
            Subject(name="Педагогика", semester=2, hours=80, control_type=0),
        ]
        db.add_all(subjects)
        db.flush()

        groups = [
            StudentGroup(name="PI-21", speciality_id=specialities[0].id, course=3),
            StudentGroup(name="IS-22", speciality_id=specialities[1].id, course=2),
            StudentGroup(name="BU-23", speciality_id=specialities[2].id, course=1),
            StudentGroup(name="EE-21", speciality_id=specialities[3].id, course=3),
            StudentGroup(name="NO-22", speciality_id=specialities[4].id, course=2),
        ]
        db.add_all(groups)
        db.flush()

        students = [
            Student(fio="Алиев Шахзод", group_id=groups[0].id, phone="+998911111111", email="aliev@student.uz", address="Ташкент", birth_date=date(2004, 2, 12)),
            Student(fio="Валиева Нодира", group_id=groups[1].id, phone="+998912222222", email="valieva@student.uz", address="Ташкент", birth_date=date(2005, 5, 20)),
            Student(fio="Хамидов Жасур", group_id=groups[2].id, phone="+998913333333", email="hamidov@student.uz", address="Самарканд", birth_date=date(2006, 3, 18)),
            Student(fio="Рахимова Севара", group_id=groups[3].id, phone="+998914444444", email="rahimova@student.uz", address="Бухара", birth_date=date(2004, 9, 7)),
            Student(fio="Турсунов Камол", group_id=groups[4].id, phone="+998915555555", email="tursunov@student.uz", address="Фергана", birth_date=date(2005, 11, 2)),
        ]
        db.add_all(students)
        db.flush()

        loads = [
            DisciplineLoad(subject_id=subjects[0].id, teacher_id=teachers[0].id, group_id=groups[0].id, lecture_hours=32, practical_hours=24, lab_hours=30, other_hours=10, control_hours=4),
            DisciplineLoad(subject_id=subjects[1].id, teacher_id=teachers[1].id, group_id=groups[1].id, lecture_hours=30, practical_hours=30, lab_hours=20, other_hours=10, control_hours=4),
            DisciplineLoad(subject_id=subjects[2].id, teacher_id=teachers[2].id, group_id=groups[2].id, lecture_hours=28, practical_hours=32, lab_hours=0, other_hours=12, control_hours=2),
            DisciplineLoad(subject_id=subjects[3].id, teacher_id=teachers[3].id, group_id=groups[3].id, lecture_hours=34, practical_hours=20, lab_hours=28, other_hours=10, control_hours=4),
            DisciplineLoad(subject_id=subjects[4].id, teacher_id=teachers[4].id, group_id=groups[4].id, lecture_hours=26, practical_hours=30, lab_hours=0, other_hours=12, control_hours=2),
        ]
        db.add_all(loads)
        db.flush()

        base = date(2026, 9, 7)
        weeks = [StudyWeek(name=f"{i + 1}-неделя", start_date=base + timedelta(days=7 * i), end_date=base + timedelta(days=7 * i + 5)) for i in range(5)]
        db.add_all(weeks)
        db.flush()

        for i, student in enumerate(students):
            db.add(Attendance(student_id=student.id, day_date=base + timedelta(days=i), pair_num=(i % 4) + 1, mark=i % 3))
            db.add(Performance(student_id=student.id, discipline_id=loads[i].id, teacher_id=teachers[i].id, control_type=subjects[i].control_type, tour_num=1, mark=min(5, i + 1)))
            db.add(Execution(teacher_id=teachers[i].id, discipline_id=loads[i].id, lectures=8 + i, practicals=6 + i, labs=i, other_works=2 + i))
            db.add(Schedule(study_week_id=weeks[i].id, day_num=i + 1, pair_num=(i % 3) + 1, subject_id=subjects[i].id, teacher_id=teachers[i].id, lesson_type=i % 4, classroom_id=classrooms[i].id, group_id=groups[i].id))

        db.add_all(
            [
                User(username="admin", hashed_password=get_password_hash("admin123"), role="Admin"),
                User(username="teacher", hashed_password=get_password_hash("teacher123"), role="Teacher"),
            ]
        )
        db.commit()
        print("Seed completed. Users: admin/admin123, teacher/teacher123")
    finally:
        db.close()


if __name__ == "__main__":
    main()
