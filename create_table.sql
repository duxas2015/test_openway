create table account_balance (
  account_id number,
  balance    number
  )
/  
create sequence account_seq
/
alter table account_balance add constraint account_balance_account_id_pk primary key ( account_id )
/

-- Possible It can be the table partitioned by end_time
create table  account_balance_history (
  account_id number,
  balance    number,
  start_time date,
  end_time   date
  )
/  

create index acc_bal_hist_end_time_acc_id_i on account_balance_history ( end_time, account_id )
/
  
create table payment (
  pay_id     number,
  account_id number,
  pay_date   date,
  amount     number
  )  
/  

create sequence payment_seq
/
alter table payment add constraint payment_pay_id_pk primary key ( pay_id )
/
create index payment_account_id on payment ( account_id )
/
alter table payment add constraint payment_account_id_fk foreign key ( account_id ) references account_balance ( account_id )
/
  
create table charge (
  charge_id  number,
  account_id number,
  charge_date date,
  amount      number
  )
/    

create sequence charge_seq
/
alter table charge add constraint charge_charge_id_pk primary key ( charge_id )
/
create index charge_account_id_i on charge ( account_id )
/
alter table charge add constraint charge_account_id_fk foreign key ( account_id ) references account_balance ( account_id )
/
