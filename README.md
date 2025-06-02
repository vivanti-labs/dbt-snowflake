# dbt-snowflake

We write a lot of dbt code to manage our customers' Snowflake
instances.  Over the years, we've collected quite a few
interesting macros for building things outside the scope of views
and tables.

This library packages those macros up, with some documentation,
for the rest of the data world to enjoy!

## Installation

To start using these wonderful macros in your dbt project, add the
following to your `packages.yml` in the root of your project
directory:

```yml
packages:
  - git: 'https://github.com/vivanti-labs/dbt-snowflake.git'
    revision: v3.2.0
```

You can also pull [any of our other tags][tags] if that suits you.

[tags]: https://github.com/vivanti-labs/dbt-snowflake/tags

## Usage

To use the materializations, reference them in the `config(...)`
call (on a per-model basis) like so:

```jinja2
{{
    config(
      materialized = 'external_table'
    )
}}
```

Alternatively, you can use the `dbt_project.yml` to set the
materialization for all models based on directory structure:

```yaml
models:
  your_project:
    procs:
      +materialized: procedure
```

Keep in mind that several materializations are only truly useful
if you supply additional configuration, which likely needs
specified in the model file anyway.



### Materialization: Empty Tables

Sometimes you just need a table to exist, because you're going to
use it with a stored procedure to log audit events or something.
That's where the `empty_table` materialization comes in.

You feed it a DDL body:

```sql
-- models/audit_log.sql
{{ config(materialized = 'empty_table') }}
(
   logged_at timestamp without timezone,
   logged_by text,
   message   text
)
```

... and it will dutifully call `CREATE TABLE IF NOT EXISTS` for
you.  Then, you can use the `ref(...)` operator in your stored
procedure logic as you need!

Note that if oyu change the definition of the table, the macro
won't care.  You will have to manually `ALTER TABLE` it, or drop
it and let dbt recreate it (as it then will no longer exist).

#### Configuration Parameters

The following can / should be set via the `config()` call:

  - **materialized** (required) - set to `'empty_table'`

There are actually no real configuration options for empty tables.



### Materialization: External Tables

The `external_table` materialization allows you to create tables
in Snowflake that are backed by files in a stage (Parquet, Avro,
CSV -- you get to decide!)

```sql
-- models/external_table.sql
{{ config(materialized = 'external_table') }}
location     = @{{ ref('your_stage') }}
file_format  = {{ ref('json') }}
pattern      = '.*/dat.*.json'
auto_refresh = false
```

If you run your `dbt build` in full-refresh mode, the external
table will be recreated.  Otherwise, it will only be created if it
does not already exist.

In the above example, we used a `ref(...)` to a stage, and another
to a file format.  You can create those objects with the `generic
` materialization, documented below.

#### Configuration Parameters

The following can / should be set via the `config()` call:

  - **materialized** (required) - set to `'external_table'`

There are actually no real configuration options for external
tables, since the behaviors can be specified in the generative SQL.

Refer to the [Snowflake documentation for CREATE EXTERNAL
TABLE][ext-table] for more possibilities.

[ext-table]: https://docs.snowflake.com/en/sql-reference/sql/create-external-table



### Materialization: Generic

Lots of objects in Snowflake use the same basic DDL format:

```sql
create or replace TYPE NAME
...

create TYPE if not exists NAME
...
```

Where the `...` bits are something you would want to specify in
the body of your dbt model anyway.  For these types of objects
(like stages, integrations, file formatts, etc.) the `generic`
materialization is there for you:

```sql
-- models/parquet.sql
{{ config(materialized = 'generic', type = 'file format') }}
type = parquet

-- models/uploads.sql
{{ config(materialized = 'generic', type = 'stage') }}
storage_integration = {{ var('storage_integration') }}
url = '{{ var("storage_bucket_url") }}'
directory = (enable = true)
```

etc.

#### Configuration Parameters

The following can / should be set via the `config()` call:

  - **materialized** (required) - set to `'generic'`
  - **type** (required) - the type of the Snowflake object to
    create, like `'file format'` or `'stage'`.



### Materialization: Materialized View

The `materialized_view` materialization allows you to create
tables that Snowflake will derive from a SQL query, yet allocate
storage for (and keep replenishing it as new data comes in!)

_Note: Materialized Views are an **Enterprise Edition** feature,
and no amount of dbt macro magic can upgrade you to that level._

```sql
-- models/expensive_aggregate.sql
{{ config(materialized = 'materialized_view') }}
select product_name,
       count(sale_id)  as sales_tally,
       sum(sale_total) as sales_total
  from {{ ref('raw_sales_detail') }}
 group by product_name
```

If you run your `dbt build` in full-refresh mode, the materialized
view will be recreated.  Otherwise, it will only be created if it
does not already exist.

#### Configuration Parameters

The following can / should be set via the `config()` call:

  - **materialized** (required) - set to `'materialized_view'`

There are actually no real configuration options for materialized
views, since the behaviors can be specified in the generative SQL.

Refer to the [Snowflake documentation on materialized
views][mat-views] for more ideas.

[mat-views]: https://docs.snowflake.com/en/sql-reference/sql/create-materialized-view

### Materialization: Stored Procedures and Functions

The `procedure` materialization allows you to create a Snowflake
stored procedure via `CREATE PROCEDURE`:

```sql
{{
    config(
      materialized = 'procedure',
      signature = '(text, text, text)',
      previously = [
        '(text, text)'
      ]
    )
}}
(a text, b text, c text)
returns text
language sql
execute as caller
as
$$
begin
  return 'a=' || a || '; b=' || b || '; c=' || c;
end;
$$
```

If you want a UDF (or a UDTF) use the `function` materialization
instead; everything else is the same between the two types,
configuration-wise.

One nice thing about building your stored procedures (or
user-defined functions) via dbt is that you can chain procedure
calls using the built-in `ref()` operators.  To illustrate, assume
we have a model in our dbt project called `AUDIT(TEXT)` that takes
a log message and writes it to an auditing table.  It might look
like this:

```sql
-- models/audit.sql
{{
    config(
      materialized = 'procedure',
      signature    = '(text)'
    )
}}
(msg text)
returns text
language sql
execute as owner
as $$
  insert into audit.logs.messages -- fixed global table
    (logged_at, logged_by, message)
  select current_timestamp(),
         current_user(),
         :msg
  ;
$$
```

Then, if we need to log something in _another_ procedure, we can
reference the audit function without needing to know what database
or schema we are building against:

```sql
-- models/do_something.sql
{{
    config(
      materialized = 'procedure',
    )
}}
()
returns text
language sql
execute as owner
as $$
  call {{ ref('audit') }}('starting to do something!');
  -- actually do something
  call {{ ref('audit') }}('we just did something!');
$$
```

Procedures are re-created every time dbt needs to build them,
primarily to ensure that the latest code is in effect.  This means
that if you do need to grant privileges to your stored procedures
(to allow other roles to call them) you'll want the `grants`
config parameter (see below for the definition and even more below
for an example).

#### Configuration Parameters

The following can / should be set via the `config()` call:

  - **materialized** (required) - set to `'procedure'` for a
    stored procedure, or `'function'` for a user-defined function.

  - **signature** - The type signature of the procedure, withoout
    the formal parameter names.  Defaults to `'()'`, for
    procedures that do not take any arguments.

  - **previously** - A list of prior type signatures, used to
    _explicitly DROP PROCEDURE_ prior versions of this model.
    This is used to clean up after older versions of the code that
    a `CREATE OR REPLACE` cannot affect owing to added or removed
    parameters.

  - **grants** - A map of privileges to grant and a list of roles
    to grant them to, after the procedure has been created.

#### Procedure (or Function) Examples

Here's the simplest stored procedure model:

```sql
{{ config(materialized = 'procedure') }}
() -- no parameters
return text
language sql
execute as caller
as $$
  return 42;
$$
```

Here's a more complicated procedure that takes two text parameters
(but used to only take one):

```sql
{{
    config(
      materialized = 'procedure',
      signature    = '(text, text)',
      previously   = [
        '(text)'
      ]
    )
}}
(first text, second text)
returns text
language sql
as $$
  return first || '.' || second;
$$
```

Here's that same procedure, but we grant USAGE rights on the
procedure to the role `VV_DATA_VIEWER` automatically:

```sql
{{
    config(
      materialized = 'procedure',
      signature    = '(text, text)',
      previously   = [
        '(text)'
      ],
      grants = {
        'USAGE': [
                  'VV_DATA_VIEWER'
                 ]
      }
    )
}}
(first text, second text)
returns text
language sql
as $$
  return first || '.' || second;
$$
```



### Materialization: Task

The `task` materialization creates and optionally resumes a TASK
in your Snowflake instance.

```sql
-- models/send_alerts_daily.sql
{{
    config(
      materialized = 'task',
      running = true
    )
}}
allow_overlapping_execution = false
warehouse = {{ var('warehouse') }}
schedule  = 'using cron 15 11 * * * UTC'

as
  call {{ ref('send_alerts') }}()
```

This type of model pairs well with a `procedure` materialized
model, and the `ref(...)` trick for calling it.

#### Configuration Parameters

The following can / should be set via the `config()` call:

  - **materialized** (required) - set to `'task'`.

  - **running** - a boolean that determines if the task should
    be resumed after it is created.  Defaults to false (the task
    will remain in the SUSPENDED state).


