-- MariaDB 10.11.14 (Ubuntu 24.04 package) returns 0 here; the right answer
-- is the number of open issues in project 1 (6 in the e2e seed). Core's
-- IssueQuery for a member of a public project whose role sees all issues.
-- Correct with SET optimizer_switch='semijoin=off' (or materialization=off).
SELECT count(*) FROM issues
INNER JOIN projects ON projects.id = issues.project_id
INNER JOIN issue_statuses ON issue_statuses.id = issues.status_id
WHERE (((projects.status IN (1, 5) AND EXISTS (SELECT 1 AS one FROM enabled_modules em WHERE em.project_id = projects.id AND em.name='issue_tracking'))
  AND (((projects.is_public = TRUE AND projects.id NOT IN (SELECT project_id FROM members WHERE user_id IN (8,3)))
        AND ((issues.is_private = FALSE OR issues.author_id = 8 OR issues.assigned_to_id IN (8))))
       OR (projects.id IN (1) AND (1=1)))))
  AND ((issues.status_id IN (SELECT id FROM issue_statuses WHERE is_closed=FALSE)) AND projects.id = 1);
