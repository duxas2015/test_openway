create or replace package body pkg_test_account_operation is

  procedure clear_data
    is
    begin
      delete from account_balance_history;
      delete from payment;
      delete from charge;
      delete from account_balance;
      commit;
    end clear_data;    

  procedure set_fixed_date ( i_date date default null ) 
    is
      v_default_date_format varchar2(4000 char);
      v_execute_str varchar2( 4000 char );
    begin
      if ( i_date is null ) then
        execute immediate 'alter system set fixed_date = none';
      else  
        select value into v_default_date_format from nls_session_parameters where parameter = 'NLS_DATE_FORMAT';
        v_execute_str := 'alter system set fixed_date = ''' || to_char( i_date, v_default_date_format ) || '''';
        execute immediate v_execute_str;
      end if;  
    end set_fixed_date;

  procedure set_fixed_date ( i_date varchar2 default null ) 
    is
      v_default_date_format varchar2(4000 char);
      v_execute_str varchar2( 4000 char );
      v_date date;
    begin
      if ( i_date is null ) then
        execute immediate 'alter system set fixed_date = none';
      else  
        select value into v_default_date_format from nls_session_parameters where parameter = 'NLS_DATE_FORMAT';
        v_date := to_date(i_date,'dd.mm.yyyy hh24:mi:ss');
        v_execute_str := 'alter system set fixed_date = ''' || to_char( v_date, v_default_date_format ) || '''';
        execute immediate v_execute_str;
      end if;  
    end set_fixed_date;

begin
  null;
end pkg_test_account_operation;
/
