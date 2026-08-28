create table todos (
  id text primary key,
  body text not null,
  done integer not null default 0,
  deleted integer not null default 0,
  updated_at real not null
);
