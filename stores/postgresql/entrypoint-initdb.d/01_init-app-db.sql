CREATE TABLE staff (
  PersonId SERIAL PRIMARY KEY,
  LastName varchar(255),
  FirstName varchar(255),
  Company varchar(255)
);

GRANT ALL ON staff TO "vault" WITH GRANT OPTION;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO "vault" WITH GRANT OPTION;
