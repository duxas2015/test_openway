PL/SQL Developer Test script 3.0
104
declare
  v_account_id account_balance.account_id%type;
  v_balance number;
  v_sum number;
begin
    -- clear the stand
    pkg_test_account_operation.clear_data();

    -- create the case
    pkg_test_account_operation.set_fixed_date ( '01.01.2021 10:00:00' );
    -- create account
    pkg_account_operation.create_account(o_account_id => v_account_id);

    pkg_test_account_operation.set_fixed_date ( '01.01.2021 10:01:00' );
    -- make payment
    pkg_account_operation.make_payment(
      i_account_id => v_account_id, 
      i_amount => 100 
      );

    pkg_test_account_operation.set_fixed_date ( '01.02.2021 10:00:00' );
    -- make charge
    pkg_account_operation.make_charge(
      i_account_id => v_account_id, 
      i_amount => 50 
      );
      
    pkg_test_account_operation.set_fixed_date ( '01.02.2021 14:00:00' );
    -- make charge
    pkg_account_operation.make_charge(
      i_account_id => v_account_id, 
      i_amount => 10 
      );
      
    pkg_test_account_operation.set_fixed_date ( '15.02.2021 10:01:00' );
    -- make payment
    pkg_account_operation.make_payment(
      i_account_id => v_account_id, 
      i_amount => 100 
      );

    pkg_test_account_operation.set_fixed_date ( '01.02.2022 10:00:00' );
    -- make payment
    pkg_account_operation.make_payment(
      i_account_id => v_account_id, 
      i_amount => 100
      );

    -- check data
    -- get current balance
    pkg_account_operation.get_account_balance(
      i_account_id => v_account_id, 
      o_balance => v_balance 
      );
    dbms_output.put_line ( 'current balance: ' || v_balance );   

    -- get balance at the date defined
    pkg_account_operation.get_account_balance(
      i_account_id => v_account_id, 
      i_date => to_date('02.01.2021 11:00','dd.mm.yyyy hh24:mi'), 
      o_balance => v_balance 
      );
    dbms_output.put_line ( 'balance at 02.01.2021 11:00: ' || v_balance );   

    -- get balance at the date defined
    pkg_account_operation.get_account_balance(
      i_account_id => v_account_id, 
      i_date => to_date('03.01.2021 11:00','dd.mm.yyyy hh24:mi'), 
      o_balance => v_balance 
      );
    dbms_output.put_line ( 'balance at 03.01.2021 11:00: ' || v_balance );   
    
    -- get debet flow for the period provided
    pkg_account_operation.get_debet_flow(
      i_account_id => v_account_id,
      i_start_time => to_date('01.01.2021 00:00','dd.mm.yyyy hh24:mi'),
      i_end_time   => to_date('01.03.2022 00:00','dd.mm.yyyy hh24:mi'),
      o_sum        => v_sum
      );
    dbms_output.put_line ( 'debet flow: ' || v_sum );                                         
    
    -- get credit flow for the period provided
    pkg_account_operation.get_credit_flow(
      i_account_id => v_account_id,
      i_start_time => to_date('01.01.2021 00:00','dd.mm.yyyy hh24:mi'),
      i_end_time   => to_date('01.03.2022 00:00','dd.mm.yyyy hh24:mi'),
      o_sum        => v_sum
      );
    dbms_output.put_line ( 'credit flow: ' || v_sum );

    -- get interest for the period provided
    pkg_account_operation.get_interest(
      i_account_id    => v_account_id,
      i_start_date    => to_date('01.01.2021 00:00','dd.mm.yyyy hh24:mi'),
      i_end_date      => to_date('01.03.2022 00:00','dd.mm.yyyy hh24:mi'),
      i_interest_rate => .1,
      o_sum           => v_sum
      );
    
    dbms_output.put_line ( 'total interest: ' || v_sum );
    
    -- finish the test
    pkg_test_account_operation.set_fixed_date();
end;
0
0
