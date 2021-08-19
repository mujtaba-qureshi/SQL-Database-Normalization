-- creating tables DDL
CREATE TABLE "users" (
    "id" SERIAL PRIMARY KEY,
    "username" VARCHAR(25) UNIQUE,
    "last_login" TIMESTAMP
);

CREATE TABLE "topics" (
    "id" SERIAL PRIMARY KEY,
    "name" VARCHAR(30) UNIQUE,
    "description" VARCHAR(500),
    "user_id" INTEGER REFERENCES "users"
);

CREATE TABLE "posts" (
    "id" SERIAL PRIMARY KEY,
    "title" VARCHAR(100),
    "url" VARCHAR DEFAULT NULL,
    "text_content" TEXT DEFAULT NULL,
    "topic_id" INTEGER REFERENCES "topics" ON DELETE CASCADE,
    "user_id" INTEGER REFERENCES "users" ON DELETE SET NULL,
    "post_time" TIMESTAMP
    CONSTRAINT "content_check" CHECK (("url" IS NOT NULL AND "text_content" IS NULL) OR ("url" IS NULL AND "text_content" IS NOT NULL))
);

CREATE TABLE "comments" (
    "id" SERIAL PRIMARY KEY,
    "user_id" INTEGER REFERENCES "users" ON DELETE SET NULL,
    "post_id" INTEGER REFERENCES "posts" ON DELETE CASCADE,
    "parent_comment" INTEGER REFERENCES "comments"("id") ON DELETE CASCADE,
    "content" TEXT
);

CREATE TABLE "user_votes" (
    "id" SERIAL PRIMARY KEY,
    "user_id" INTEGER REFERENCES "users" ON DELETE SET NULL,
    "post_id" INTEGER REFERENCES "posts" ON DELETE CASCADE,
    "vote" SMALLINT,
    CONSTRAINT "vote_only_once" UNIQUE ("user_id", "post_id")
);


-- adding constraints to the tables
ALTER TABLE "topics" ADD CONSTRAINT "topic_name_not_empty" CHECK (LENGTH(TRIM("name"))>0),
    ALTER COLUMN "name" SET NOT NULL;
ALTER TABLE "topics" ALTER COLUMN "user_id" SET NOT NULL;
ALTER TABLE "topics" ALTER COLUMN "user_id" SET DEFAULT 1; -- doing this to allow data entry in current format


ALTER TABLE "users" ADD CONSTRAINT "username_not_empty" CHECK (LENGTH(TRIM("username"))>0),
     ALTER COLUMN "username" SET NOT NULL;

ALTER TABLE "posts" ADD CONSTRAINT "post_title_not_empty" CHECK (LENGTH(TRIM("title"))>0),
     ALTER COLUMN "title" SET NOT NULL;
ALTER TABLE "posts" ALTER COLUMN "topic_id" SET NOT NULL;

ALTER TABLE "comments" ADD CONSTRAINT "comment_content_not_empty" CHECK (LENGTH(TRIM("content"))>0),
     ALTER COLUMN "content" SET NOT NULL;
ALTER TABLE "comments" ALTER COLUMN "post_id" SET NOT NULL,
    ALTER COLUMN "parent_comment" SET NOT NULL;
ALTER TABLE "comments" ALTER COLUMN "parent_comment" SET DEFAULT 1; -- doing this to allow data entry in current format

ALTER TABLE "user_votes" ADD CONSTRAINT "voting_system" CHECK ("vote" = 1 OR "vote" = -1);
ALTER TABLE "user_votes" ALTER COLUMN "post_id" SET NOT NULL;

-- creating indexes
CREATE INDEX "search_post_topic_time" ON "posts" ("topic_id", "post_time");
CREATE INDEX "search_post_user_time" ON "posts" ("user_id", "post_time");
CREATE INDEX "search_child_comment" ON "comments" ("parent_comment");
CREATE INDEX "search_user_comment" ON "comments" ("user_id");
CREATE INDEX "search_url_posts" ON "posts" ("url");
CREATE INDEX "search_post_votes" ON "user_votes" ("post_id");



-- adding data into the tables DML

-- adding ("usernames") in "users" table
INSERT INTO "users" ("username")
    SELECT regexp_split_to_table(upvotes,',') UID
    FROM bad_posts
    UNION
    SELECT regexp_split_to_table(upvotes,',') UID
    FROM bad_posts
    UNION
    SELECT username UID
    FROM bad_posts
    UNION
    SELECT username UID
    FROM bad_comments;

-- adding ("name") to "topics" table (there are no descriptions available)
INSERT INTO "topics" ("name")
    SELECT DISTINCT(topic)
    FROM bad_posts;

-- adding data into "posts"
INSERT INTO "posts" ("id", "title", "url", "text_content", "topic_id", "user_id")
    SELECT bp.id, bp.title::VARCHAR(100), bp.url, bp.text_content, t.id topic_id, u.id UID
    FROM topics t
    JOIN bad_posts bp
    ON t.name = bp.topic
    JOIN users u
    ON bp.username = u.username;

-- adding data into "comments" table
INSERT INTO "comments" ("id", "user_id", "post_id", "content")
    SELECT bc.id, u.id UID, bc.post_id, bc.text_content
    FROM users u
    JOIN bad_comments bc
    ON u.username = bc.username
    JOIN posts p
    ON bc.post_id = p.id;


-- adding data into "user_votes" table (by creating 2 dummy tables)

--dummy upvotes
CREATE TABLE "dummy_upvote" (
    "user_id" INTEGER,
    "post_id" INTEGER,
    "vote" INTEGER
);

INSERT INTO "dummy_upvote" ("user_id", "post_id")
    WITH t1 AS (
        SELECT bp.id post_id, regexp_split_to_table(bp.upvotes,',') uname_upvote
        FROM bad_posts bp
        )
    SELECT u.id UID, t1.post_id
    FROM t1
    JOIN users u
    ON t1.uname_upvote = u.username;

UPDATE "dummy_upvote" SET "vote" = 1;

--dummy downvotes
CREATE TABLE "dummy_downvote" (
    "user_id" INTEGER,
    "post_id" INTEGER,
    "vote" INTEGER
);

INSERT INTO "dummy_downvote" ("user_id", "post_id")
    WITH t1 AS (
        SELECT bp.id post_id, regexp_split_to_table(bp.downvotes,',') uname_downvote
        FROM bad_posts bp
        )
    SELECT u.id UID, t1.post_id
    FROM t1
    JOIN users u
    ON t1.uname_downvote = u.username;

UPDATE "dummy_downvote" SET "vote" = -1;

-- adding the dummy data into actual table of user_votes
INSERT INTO "user_votes" ("user_id", "post_id", "vote")
    SELECT *
    FROM dummy_upvote
    UNION ALL
    SELECT *
    FROM dummy_downvote;

-- deleting the dummy tables from the system
DROP TABLE "dummy_upvote";
DROP TABLE "dummy_downvote";


-- examples of DQL (Data Query Language)

-- List all users who haven’t logged in in the last year
SELECT *
FROM users
WHERE CURRENT_TIMESTAMP - last_login > INTERVAL '1 year';

-- List all users who haven’t created any post
SELECT u.id
FROM users u
LEFT JOIN posts p
ON u.id = p.user_id
WHERE p.user_id = NULL;

-- Find a user by their username.
SELECT u.username
FROM users u
WHERE u.username LIKE '%user%';

-- List all topics that don’t have any posts
SELECT t.name
FROM topics t
LEFT JOIN posts p
ON t.id = p.topic_id
WHERE p.topic_id = NULL;

-- Find a topic by its name
SELECT *
FROM topics t
WHERE t.name LIKE '%topic%';

-- List the latest 20 posts for a given topic
SELECT p.id, p.title, t.name, p.post_time
FROM posts p
JOIN topics t
ON p.topic_id = t.id
WHERE t.name LIKE '%e' -- example
ORDER BY p.post_time DESC
LIMIT 20;

-- List the latest 20 posts made by a given user.
SELECT p.id, p.title, u.username, p.post_time
FROM posts p
JOIN users u
ON p.user_id = u.id
WHERE u.username LIKE '%e' -- example
ORDER BY p.post_time DESC
LIMIT 20;

-- Find all posts that link to a specific URL, for moderation purposes.
SELECT *
FROM posts
WHERE url LIKE '%www.specific_URL%';

-- List all the top-level comments (those that don’t have a parent comment) for a given post.
SELECT *
FROM comments
WHERE parent_comment IS NULL;

-- List all the direct children of a parent comment.
SELECT *
FROM comments
WHERE parent_comment = 2 -- example comment_id;

-- List the latest 20 comments made by a given user.
SELECT u.username, c.post_id, c.parent_comment, c.content
FROM comments c
JOIN users u
ON c.user_id = u.id
WHERE u.username = '%example%';

-- Compute the score of a post, defined as the difference between the number of upvotes and the number of downvotes
SELECT post_id, SUM(vote) tot_score
FROM user_votes
GROUP BY 1
ORDER BY 2 DESC;
