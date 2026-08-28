create table todos (
  id integer primary key,
  body text not null,
  done integer not null default 0
);
