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
const attendanceMarks = {
  '0': 'Отсутствовал',
  '1': 'Опоздал',
  '2': 'Присутствовал',
};
const performanceMarks = {
  '0': 'Недопуск',
  '1': 'Неявка',
  '2': 'Неудовлетворительно',
  '3': 'Удовлетворительно',
  '4': 'Хорошо',
  '5': 'Отлично',
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
        label: 'ID факультета',
        type: FieldType.number,
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
        label: 'ID специальности',
        type: FieldType.number,
      ),
      EntityField(key: 'course', label: 'Курс', type: FieldType.number),
    ],
  ),
  EntityDefinition(
    title: 'Студенты',
    route: '/students',
    endpoint: '/students',
    columns: ['fio', 'group_id', 'phone', 'email'],
    fields: [
      EntityField(key: 'fio', label: 'ФИО'),
      EntityField(key: 'group_id', label: 'ID группы', type: FieldType.number),
      EntityField(key: 'phone', label: 'Телефон', required: false),
      EntityField(key: 'email', label: 'Email', type: FieldType.email),
      EntityField(key: 'address', label: 'Адрес', required: false),
      EntityField(
        key: 'birth_date',
        label: 'Дата рождения',
        type: FieldType.date,
      ),
    ],
  ),
  EntityDefinition(
    title: 'Преподаватели',
    route: '/teachers',
    endpoint: '/teachers',
    columns: ['fio', 'position', 'phone'],
    fields: [
      EntityField(key: 'fio', label: 'ФИО'),
      EntityField(key: 'scientific_degree', label: 'Степень', required: false),
      EntityField(key: 'academic_title', label: 'Звание', required: false),
      EntityField(key: 'position', label: 'Должность'),
      EntityField(key: 'phone', label: 'Телефон', required: false),
      EntityField(key: 'email', label: 'Email', type: FieldType.email),
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
    columns: ['subject_id', 'teacher_id', 'group_id'],
    fields: [
      EntityField(
        key: 'subject_id',
        label: 'ID предмета',
        type: FieldType.number,
      ),
      EntityField(
        key: 'teacher_id',
        label: 'ID преподавателя',
        type: FieldType.number,
      ),
      EntityField(key: 'group_id', label: 'ID группы', type: FieldType.number),
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
        label: 'ID преподавателя',
        type: FieldType.number,
      ),
      EntityField(
        key: 'discipline_id',
        label: 'ID дисциплины',
        type: FieldType.number,
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
