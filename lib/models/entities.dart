import 'package:flutter/material.dart';
import 'entity_model.dart';

const classroomTypes = {
  'кк': 'Компьютерный',
  'лк': 'Лекционная',
  'пк': 'Практическая',
  'лб': 'Лаборатория',
};
const controlTypes = {'0': 'Зачет', '1': 'Экзамен'};
const lessonTypes = {
  '0': 'Лекция',
  '1': 'Практика',
  '2': 'Лабораторная',
  '3': 'Другое',
};
/// Attendance only stores *exceptions* — a student with no record for a
/// lesson is presumed present. These are the two values a stored row can
/// take; there is no "present" entry because presence is never written.
const attendanceMarks = {
  '0': 'Отсутствовал',
  '1': 'Опоздал',
};
const performanceMarks = {
  '0': 'Недопуск',
  '1': 'Неявка',
  '2': 'Неудовл.',
  '3': 'Удовл.',
  '4': 'Хорошо',
  '5': 'Отлично',
};

/// Зачёт (control_type == 0) only ever uses four of the shared 0-5 marks:
/// недопуск, неявка, не зачёт, зачёт. Экзамен uses the full scale via
/// [performanceMarks] above.
const creditMarkValues = [0, 1, 2, 3];
const creditMarkLabels = {
  0: 'Недопуск',
  1: 'Неявка',
  2: 'Не зачет',
  3: 'Зачет',
};

/// Compact abbreviations shown inside grid/journal cells, where a full
/// word like "Недопуск" would not fit. Keyed by control type so зачёт and
/// экзамен can share the same 0/1 (недопуск/неявка) meaning while diverging
/// on what 2 and above mean.
const creditMarkShort = {0: 'Н/Д', 1: 'Н/Я', 2: 'не зач.', 3: 'зачет'};
const examMarkShort = {
  0: 'Н/Д',
  1: 'Н/Я',
  2: 'неуд',
  3: 'удовл',
  4: 'хор',
  5: 'отл',
};

/// Full-word label for a mark, control-type aware. Use in dialogs,
/// confirmations and anywhere space isn't tight.
String markLabel(int controlType, int value) {
  if (controlType == 0) return creditMarkLabels[value] ?? '$value';
  return performanceMarks['$value'] ?? '$value';
}

/// Compact label for a mark, control-type aware. Use inside grid cells
/// (gradebook journal, performance grid) where a badge is a few chars wide.
String markShortLabel(int controlType, int value) {
  if (controlType == 0) return creditMarkShort[value] ?? '$value';
  return examMarkShort[value] ?? '$value';
}

/// Valid mark values for a given control type, in display order.
List<int> markValuesFor(int controlType) =>
    controlType == 0 ? creditMarkValues : (performanceMarks.keys.map(int.parse).toList()..sort());

/// Shared color for a mark, control-type aware, used across the gradebook,
/// performance grid and student portal so a given mark always reads the
/// same color everywhere in the app.
const _markColors = {
  0: Color(0xFF374151), // недопуск
  1: Color(0xFF6B7280), // неявка
};
Color markColor(int controlType, int value) {
  if (_markColors.containsKey(value)) return _markColors[value]!;
  if (controlType == 0) {
    return value == 3 ? const Color(0xFF10B981) : const Color(0xFFEF4444);
  }
  return switch (value) {
    5 => const Color(0xFF10B981),
    4 => const Color(0xFF3B82F6),
    3 => const Color(0xFFF59E0B),
    _ => const Color(0xFFEF4444),
  };
}

/// Lesson type colors for schedule cards
const lessonTypeColors = {
  0: Color(0xFF3B82F6), // Лекция — синий
  1: Color(0xFF10B981), // Практика — зеленый
  2: Color(0xFFF59E0B), // Лабораторная — оранжевый
  3: Color(0xFF8B5CF6), // Другое — фиолетовый
};

/// Icons for each entity in the navigation
const entityIcons = {
  '/faculties': Icons.account_balance_outlined,
  '/specialities': Icons.auto_stories_outlined,
  '/groups': Icons.groups_outlined,
  '/students': Icons.person_outlined,
  '/teachers': Icons.cast_for_education_outlined,
  '/subjects': Icons.menu_book_outlined,
  '/disciplines': Icons.science_outlined,
  '/classrooms': Icons.meeting_room_outlined,
  '/study-weeks': Icons.date_range_outlined,
  '/execution': Icons.assignment_turned_in_outlined,
};

const entityDefinitions = <EntityDefinition>[
  EntityDefinition(
    title: 'Факультеты',
    route: '/faculties',
    endpoint: '/faculties',
    columns: ['name'],
    fields: [EntityField(key: 'name', label: 'Название')],
  ),
  EntityDefinition(
    title: 'Специальности',
    route: '/specialities',
    endpoint: '/specialities',
    columns: ['name', 'faculty_id'],
    fields: [
      EntityField(key: 'name', label: 'Название'),
      EntityField(
        key: 'faculty_id',
        label: 'Факультет',
        type: FieldType.fkSelect,
        refEndpoint: '/faculties',
      ),
    ],
  ),
  EntityDefinition(
    title: 'Группы',
    route: '/groups',
    endpoint: '/groups',
    columns: ['name', 'speciality_id', 'course'],
    fields: [
      EntityField(key: 'name', label: 'Название'),
      EntityField(
        key: 'speciality_id',
        label: 'Специальность',
        type: FieldType.fkSelect,
        refEndpoint: '/specialities',
      ),
      EntityField(key: 'course', label: 'Курс', type: FieldType.number),
    ],
  ),
  EntityDefinition(
    title: 'Студенты',
    route: '/students',
    endpoint: '/students',
    columns: ['fio', 'faculty_id', 'speciality_id', 'group_id', 'phone'],
    fields: [
      EntityField(key: 'fio', label: 'ФИО', type: FieldType.fio),
      // Факультет → Специальность → Группа: каскадная фильтрация
      EntityField(
        key: 'faculty_id',
        label: 'Факультет',
        type: FieldType.fkSelect,
        refEndpoint: '/faculties',
      ),
      EntityField(
        key: 'speciality_id',
        label: 'Направление',
        type: FieldType.fkSelect,
        refEndpoint: '/specialities',
        dependsOn: ['faculty_id'],
        foreignKey: 'faculty_id',
      ),
      // Курс — выбор из списка (в университете максимум 4 курса)
      // EntityField(
      //   key: 'course',
      //   label: 'Курс',
      //   type: FieldType.select,
      //   options: {'1': '1 курс', '2': '2 курс', '3': '3 курс', '4': '4 курс'},
      // ),
      EntityField(
        key: 'group_id',
        label: 'Группа',
        type: FieldType.fkSelect,
        refEndpoint: '/groups',

        dependsOn: [
          'speciality_id',
          'course',
        ],
      ),
      EntityField(
        key: 'birth_date',
        label: 'Дата рождения',
        type: FieldType.date,
      ),
      EntityField(key: 'phone', label: 'Телефон', required: false, type: FieldType.phone),
      EntityField(
        key: 'email',
        label: 'Email',
        type: FieldType.email,
        required: true,
      ),
      EntityField(key: 'address', label: 'Адрес', required: false),
    ],
  ),
  EntityDefinition(
    title: 'Преподаватели',
    route: '/teachers',
    endpoint: '/teachers',
    columns: ['fio', 'position', 'phone'],
    fields: [
      EntityField(key: 'fio', label: 'ФИО', type: FieldType.fio),
      EntityField(key: 'scientific_degree', label: 'Степень', required: false, type: FieldType.fio),
      EntityField(key: 'academic_title', label: 'Звание', required: false, type: FieldType.fio),
      EntityField(key: 'position', label: 'Должность', required: false, type: FieldType.fio),
      EntityField(key: 'phone', label: 'Телефон', required: false, type: FieldType.phone),
      EntityField(
        key: 'email',
        label: 'Email',
        type: FieldType.email,
        required: false,
      ),
      EntityField(key: 'address', label: 'Адрес', required: false),
    ],
  ),
  EntityDefinition(
    title: 'Предметы',
    route: '/subjects',
    endpoint: '/subjects',
    columns: ['name', 'semester', 'hours', 'control_type'],
    fields: [
      EntityField(key: 'name', label: 'Название'),
      EntityField(key: 'semester', label: 'Семестр', type: FieldType.number),
      EntityField(key: 'hours', label: 'Часы', type: FieldType.number),
      EntityField(
        key: 'control_type',
        label: 'Контроль',
        type: FieldType.select,
        options: controlTypes,
      ),
    ],
  ),
  EntityDefinition(
    title: 'Дисциплины',
    route: '/disciplines',
    endpoint: '/disciplines',
    columns: ['subject_id', 'teacher_id', 'group_id', 'semester'],
    fields: [
      EntityField(
        key: 'subject_id',
        label: 'Предмет',
        type: FieldType.fkSelect,
        refEndpoint: '/subjects',
      ),
      EntityField(
        key: 'teacher_id',
        label: 'Преподаватель',
        type: FieldType.fkSelect,
        refEndpoint: '/teachers',
        refLabelKey: 'fio',
      ),
      EntityField(
        key: 'group_id',
        label: 'Группа',
        type: FieldType.fkSelect,
        refEndpoint: '/groups',
      ),
      EntityField(key: 'semester', label: 'Семестр', type: FieldType.number),
      EntityField(
        key: 'lecture_hours',
        label: 'Лекции',
        type: FieldType.number,
      ),
      EntityField(
        key: 'practical_hours',
        label: 'Практика',
        type: FieldType.number,
      ),
      EntityField(
        key: 'lab_hours',
        label: 'Лабораторные',
        type: FieldType.number,
      ),
      EntityField(key: 'other_hours', label: 'Прочие', type: FieldType.number),
      EntityField(
        key: 'control_hours',
        label: 'Контроль',
        type: FieldType.number,
      ),
    ],
  ),
  EntityDefinition(
    title: 'Аудитории',
    route: '/classrooms',
    endpoint: '/classrooms',
    columns: ['number', 'type'],
    fields: [
      EntityField(key: 'number', label: 'Номер'),
      EntityField(
        key: 'type',
        label: 'Тип',
        type: FieldType.select,
        options: classroomTypes,
      ),
    ],
  ),
  EntityDefinition(
    title: 'Учебные недели',
    route: '/study-weeks',
    endpoint: '/study-weeks',
    columns: ['name', 'start_date', 'end_date'],
    fields: [
      EntityField(key: 'name', label: 'Название'),
      EntityField(key: 'start_date', label: 'Начало', type: FieldType.date),
      EntityField(key: 'end_date', label: 'Конец', type: FieldType.date),
    ],
  ),
  EntityDefinition(
    title: 'Исполнение',
    route: '/execution',
    endpoint: '/execution',
    columns: ['teacher_id', 'discipline_id', 'lectures', 'practicals'],
    fields: [
      EntityField(
        key: 'teacher_id',
        label: 'Преподаватель',
        type: FieldType.fkSelect,
        refEndpoint: '/teachers',
        refLabelKey: 'fio',
      ),
      EntityField(
        key: 'discipline_id',
        label: 'Дисциплина',
        type: FieldType.fkSelect,
        refEndpoint: '/disciplines',
        refLabelKey: 'displayName',
      ),
      EntityField(key: 'lectures', label: 'Лекции', type: FieldType.number),
      EntityField(key: 'practicals', label: 'Практика', type: FieldType.number),
      EntityField(key: 'labs', label: 'Лабораторные', type: FieldType.number),
      EntityField(
        key: 'other_works',
        label: 'Прочие работы',
        type: FieldType.number,
      ),
    ],
  ),
];

const scheduleEntityDefinition = EntityDefinition(
  title: 'Занятие',
  route: '/schedule-crud',
  endpoint: '/schedule',
  columns: [], // We use custom UI for schedule, not EntityListScreen
  fields: [
    EntityField(
      key: 'study_week_id',
      label: 'Учебная неделя',
      type: FieldType.fkSelect,
      refEndpoint: '/study-weeks',
    ),
    EntityField(
      key: 'day_num',
      label: 'День недели',
      type: FieldType.select,
      options: {
        '1': 'Понедельник',
        '2': 'Вторник',
        '3': 'Среда',
        '4': 'Четверг',
        '5': 'Пятница',
        '6': 'Суббота',
      },
    ),
    EntityField(
      key: 'pair_num',
      label: 'Пара',
      type: FieldType.select,
      options: {
        '1': '1 пара',
        '2': '2 пара',
        '3': '3 пара',
        '4': '4 пара',
        '5': '5 пара',
        '6': '6 пара',
      },
    ),
    EntityField(
      key: 'subject_id',
      label: 'Предмет',
      type: FieldType.fkSelect,
      refEndpoint: '/subjects',
    ),
    EntityField(
      key: 'teacher_id',
      label: 'Преподаватель',
      type: FieldType.fkSelect,
      refEndpoint: '/teachers',
      refLabelKey: 'fio',
    ),
    EntityField(
      key: 'lesson_type',
      label: 'Тип занятия',
      type: FieldType.select,
      options: lessonTypes,
    ),
    EntityField(
      key: 'classroom_id',
      label: 'Аудитория',
      type: FieldType.fkSelect,
      refEndpoint: '/classrooms',
      refLabelKey: 'number',
    ),
    EntityField(
      key: 'group_id',
      label: 'Группа',
      type: FieldType.fkSelect,
      refEndpoint: '/groups',
    ),
  ],
);