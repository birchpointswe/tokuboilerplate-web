drop table todos;

create table todos (
  id text primary key,
  body text not null,
  done integer not null default 0,
  deleted integer not null default 0,
  updated_at real not null,
  synced_at real
);

create table settings (
  key text primary key,
  value text
);
