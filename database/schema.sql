create database raktadata;

create type user_role as ENUM (
'CUSTOMER',
'ADMIN',
'STAFF'
);

CREATE TYPE gender_type AS ENUM (
'MALE',
'FEMALE',
'OTHER'
);
CREATE TYPE blood_group_type AS enum (
'A+', 'A-','B+','B-','AB+','AB-','O+','O-'
);

create type component_type as enum (
'Whole Blood',
'PRBC',
'Platelets',
'FFP'
);

create type request_status as enum(
'PENDING','APPROVED','REJECTED'
);

create type urgency_type as enum(
'normal',
'emergency'
);

create type transaction_action as enum (
'DONATION_ADD',
'REQUEST_FULFILLED',
'EXPIRED',
'MANUAL_ADJUSTMENT'
);


create table users (
 user_id serial primary key,
 username varchar(50) not null unique,
 password varchar(255) not null,
 role user_role not null,
 data_of_creation timestamp not null default current_timestamp
);



