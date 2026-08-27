create table todos_tags (
  todo_id text not null,
  tag text not null,
  primary key (todo_id, tag)
);

create index todos_tags_tag on todos_tags (tag);
