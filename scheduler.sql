-- Volunteer shift scheduler for the community kitchen.
-- Week of 2025-06-09 (Monday) to 2025-06-15 (Sunday).

DROP TABLE IF EXISTS assignments;
DROP TABLE IF EXISTS shifts;
DROP TABLE IF EXISTS volunteers;

CREATE TABLE volunteers (
    volunteer_id        INTEGER PRIMARY KEY,
    name                TEXT    NOT NULL,
    max_shifts_per_week INTEGER NOT NULL
);

CREATE TABLE shifts (
    shift_id   INTEGER PRIMARY KEY,
    shift_date TEXT NOT NULL,  -- YYYY-MM-DD
    start_time TEXT NOT NULL,  -- HH:MM, 24-hour
    end_time   TEXT NOT NULL,  -- HH:MM, 24-hour
    role       TEXT NOT NULL
);

-- Copied from the sign-up sheet, so it is NOT trusted:
-- no NOT NULL and no UNIQUE here, the checks below find the problems.
CREATE TABLE assignments (
    assignment_id INTEGER PRIMARY KEY,
    shift_id      INTEGER,
    volunteer_id  INTEGER
);

INSERT INTO volunteers (volunteer_id, name, max_shifts_per_week) VALUES
    (1, 'Ana',  3),
    (2, 'Ben',  2),
    (3, 'Chen', 4),
    (4, 'Dana', 2);

INSERT INTO shifts (shift_id, shift_date, start_time, end_time, role) VALUES
    (1, '2025-06-09', '09:00', '12:00', 'Prep'),
    (2, '2025-06-09', '12:00', '15:00', 'Serving'),
    (3, '2025-06-10', '09:00', '12:00', 'Prep'),
    (4, '2025-06-10', '12:00', '15:00', 'Serving'),
    (5, '2025-06-10', '11:00', '14:00', 'Dishwashing'),
    (6, '2025-06-11', '09:00', '12:00', 'Prep'),
    (7, '2025-06-12', '16:00', '19:00', 'Cleanup'),
    (8, '2025-06-13', '09:00', '12:00', 'Delivery');

INSERT INTO assignments (assignment_id, shift_id, volunteer_id) VALUES
    (1,  1, 1),     -- Ana
    (2,  3, 1),     -- Ana
    (3,  5, 1),     -- Ana, overlaps shift 3
    (4,  6, 1),     -- Ana, her 4th shift
    (5,  1, 2),     -- Ben
    (6,  2, 2),     -- Ben, starts when shift 1 ends
    (7,  4, 3),     -- Chen
    (8,  2, 4),     -- Dana
    (9,  6, 4),     -- Dana
    (10, 6, 4),     -- Dana again: duplicate row
    (11, 7, NULL);  -- nobody confirmed yet

-- ---------------------------------------------------------------
-- Data quality checks on the assignment data
-- ---------------------------------------------------------------

-- REPORT: NULL check (assignments missing a shift or volunteer)
SELECT assignment_id, shift_id, volunteer_id
FROM assignments
WHERE shift_id IS NULL OR volunteer_id IS NULL
ORDER BY assignment_id;

-- REPORT: Uniqueness check (same volunteer on the same shift twice)
SELECT shift_id, volunteer_id, COUNT(*) AS copies
FROM assignments
WHERE shift_id IS NOT NULL AND volunteer_id IS NOT NULL
GROUP BY shift_id, volunteer_id
HAVING COUNT(*) > 1
ORDER BY shift_id, volunteer_id;

-- ---------------------------------------------------------------
-- Reports. Each one reads assignments through the same clean
-- subquery: no NULLs, and DISTINCT removes duplicate rows.
-- ---------------------------------------------------------------

-- REPORT: Schedule
SELECT s.shift_id, s.shift_date, s.start_time, s.end_time, s.role,
       v.name AS volunteer
FROM shifts s
JOIN (SELECT DISTINCT shift_id, volunteer_id
      FROM assignments
      WHERE shift_id IS NOT NULL AND volunteer_id IS NOT NULL) a
  ON a.shift_id = s.shift_id
JOIN volunteers v ON v.volunteer_id = a.volunteer_id
UNION ALL
SELECT s.shift_id, s.shift_date, s.start_time, s.end_time, s.role,
       'UNASSIGNED'
FROM shifts s
WHERE s.shift_id IN (SELECT shift_id FROM shifts
                     EXCEPT
                     SELECT shift_id FROM assignments
                     WHERE volunteer_id IS NOT NULL)
ORDER BY shift_id, volunteer;

-- REPORT: Conflict report (overlapping shifts on the same date)
SELECT v.name, s1.shift_date,
       a1.shift_id AS first_shift_id,
       a2.shift_id AS second_shift_id
FROM (SELECT DISTINCT shift_id, volunteer_id
      FROM assignments
      WHERE shift_id IS NOT NULL AND volunteer_id IS NOT NULL) a1
JOIN (SELECT DISTINCT shift_id, volunteer_id
      FROM assignments
      WHERE shift_id IS NOT NULL AND volunteer_id IS NOT NULL) a2
  ON a2.volunteer_id = a1.volunteer_id
 AND a2.shift_id > a1.shift_id
JOIN shifts s1 ON s1.shift_id = a1.shift_id
JOIN shifts s2 ON s2.shift_id = a2.shift_id
JOIN volunteers v ON v.volunteer_id = a1.volunteer_id
WHERE s1.shift_date = s2.shift_date
  AND s1.start_time < s2.end_time
  AND s2.start_time < s1.end_time
ORDER BY v.name, s1.shift_date, a1.shift_id;

-- REPORT: Validation summary (volunteers over max_shifts_per_week)
SELECT COUNT(*) AS volunteers_over_limit
FROM volunteers v
WHERE (SELECT COUNT(DISTINCT a.shift_id)
       FROM assignments a
       JOIN shifts s ON s.shift_id = a.shift_id
       WHERE a.volunteer_id = v.volunteer_id
         AND s.shift_date BETWEEN '2025-06-09' AND '2025-06-15')
      > v.max_shifts_per_week;