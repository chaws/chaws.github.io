---
title:  "Migrate Django ID field from int to big int with minimal downtime"
date:   2025-03-09 07:41:10 -0300
categories:
  - Blog
tags:
  - django
  - postgres
  - availability
---

Don't wait for your application run out of IDs! Act now!

<!--more-->

# Introduction

If you run a Django-based application created before 3.2 LTS, chances are that you might run into
an ID overflow issue. Let me explain why:

Before 3.2 LTS, Django used `int` as a data type for model IDs in the database. This means this field
can support values that fit in a signed 4-byte integer. By doing a quick search we know that this value
ranges from 0 to 2,147,483,647. That is a little over 2 billion and 100 million records.

## Reproducing the issue
Let's dive on this matter real quick. Here are a few SQL statements that reproduce this issue in PostgreSQL:

```sql
psql (17.4 (Debian 17.4-1.pgdg120+2))
Type "help" for help.

postgres=# CREATE TABLE mytable(id INTEGER);
CREATE TABLE

postgres=# INSERT INTO mytable(id) VALUES(1);
INSERT 0 1

postgres=# INSERT INTO mytable(id) VALUES(2147483647);
INSERT 0 1

postgres=# INSERT INTO mytable(id) VALUES(2147483648);
ERROR:  integer out of range
```

In the snippet above, `mytable` is created with a single field, `id` of type `INTEGER`. A few insert
commands are executed to show normal behavior and also the error when you try adding a value greater than
the upper bound range of an `INTEGER`. PostgreSQL's documentation [1] does not mention specific ranges, but
with the example above it is very clear what that limit is.

PostgreSQL behaves as expected when we insert its maximum 4-byte integer, but raises `integer out of range` if
an extra unit is added to the maximum value. This is obvious to notice if you know what you are looking for. Mix
that among Sentry notifications and hundreds of daily emails and you might find it confusing.

Although that seems a lot, it happened in a small open source project I maintain and use at the company
I work for. We use PostgreSQL as a backend RDMS. The error was very unusual and took me a while to figure
out.

In the following section I will walk you through a solution that worked pretty well on my project.

# Working on a fix

The proper fix depends heavily on how your application was designed. Generally speaking a few things need to be taken
into consideration:

* **Foreign key references**: if your target table is referenced by other tables, you'll have temporarily disable the constraint
until all data is available in the new table.

* **Data migration**: if you are fixing the issue before it happened, make sure to use some sort of data migration from the old table
to the new one with triggers or some other features your RDMS might have.

## Suggested step-by-step

Use steps below as an initial thought on how to solve it for your case.

### Step 1: Create new table based on faulty one

Create a new table with the same schema as the current one:
```sql
postgres=# CREATE TABLE mytable_new (LIKE mytable INCLUDING ALL);
CREATE TABLE

postgres=# \d
            List of relations
 Schema |    Name     | Type  |  Owner
--------+-------------+-------+----------
 public | mytable     | table | postgres
 public | mytable_new | table | postgres
(2 rows)
```

The `INCLUDING ALL` bits are PostgreSQL specific. Check your RDMS for similar syntax that copies all schema to the new table.

**NOTE**: When PostgreSQL creates the new table, sequences start from zero, so you will need to change it to the maximum value + 1 of your current sequence.

### Step 2: Set new integer type

Change `id` data type from `int` to `bigint`:

```sql
postgres=# ALTER TABLE mytable_new ALTER COLUMN id TYPE BIGINT;
ALTER TABLE

-- Now bigger values can be added
postgres=# INSERT INTO mytable_new(id) VALUES(2147483648); -- 2,147,483,647 + 1
INSERT 0 1
```

### Step 3: Swap table names (must be atomic)

This is usually very quick, by might cause some minimal downtime:

```sql
postgres=# ALTER TABLE mytable RENAME TO mytable_old;
ALTER TABLE

postgres=# ALTER TABLE mytable_new RENAME TO mytable;
ALTER TABLE
```

PostgreSQL should acquire table lock for this operation, so at this point there might be no downtime at all!
From now on, all new data will be going into the fresh new table.

### Step 4: Move data

Here is where things get tricky. And here is my suggestion:

* **If you are fixing this before it happened**: You have yourself some extra time to work this out as this post
focuses only on fixing the issue after it happened, unfortunately. Research how PostgreSQL can synchronize
two tables with all DMLs statements (INSERT, CREATE, UPDATE, DELETE).


* **If you are fixing this after it happened**: you must be panicking, I know it.
Focus now on minimizing the damage caused and just copy data starting from the most recent.

```sql
postgres=# INSERT INTO mytable SELECT * FROM mytable_old ORDER BY id DESC;
INSERT 0 2
```

In this example, PostgreSQL ran very quickly, but this depends solely on the amount of data your table has.

At this point, all new inserts are going to be working, but access to old data is still going to take some time.

# Conclusion

By researching the topic, it seems to have happened on Ruby on Rails as well and that took Basecamp down [2] for a couple of hours.
Other people might have known this for a some time now [3] and are already looking to fix this issue before it happens.

Generally speaking, when most frameworks were created more than 15 years ago, people did not expect these things to happen. I still remember
going into database classes and teachers bragging about how long it would take to reach the maximum number of a regular integer. And how using
and integer is much more space-efficient than using an 8-byte integer. Well this time has arrived and the disk-usage excuse for not using big integers
has fallen apart. 

I think we will be seeing this issue exploding here and there if not taken care of first.

My two cents: **bump this on your priority list!**


[1] https://www.postgresql.org/docs/current/datatype-numeric.html#DATATYPE-INT

[2] https://signalvnoise.com/svn3/update-on-basecamp-3-being-stuck-in-read-only-as-of-nov-8-922am-cst/

[3] https://stackoverflow.com/questions/54795701/migrating-int-to-bigint-in-postgressql-without-any-downtime
