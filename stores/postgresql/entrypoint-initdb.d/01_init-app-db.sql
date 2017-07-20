CREATE TABLE staff (
  PersonId int,
  LastName varchar(255),
  FirstName varchar(255),
  Company varchar(255)
);

GRANT ALL ON public.staff TO "vault" WITH GRANT OPTION;
