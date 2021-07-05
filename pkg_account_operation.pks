create or replace package pkg_account_operation is

  -- global constants
  gl_commit_no            constant number(1) := 0;
  gl_commit_yes           constant number(1) := 1;
  gl_history_max_date     constant date      := to_date( '31.12.2999 23:59:59', 'DD.MM.RRRR HH24:MI:SS' );

  procedure create_account (
    i_init_balance in  account_balance.balance%type default 0, -- initial balance if present
    i_commit       in  number default gl_commit_yes, -- commit management: 1 - inside current procedure; 0 - outside current procedure
    o_account_id   out account_balance.account_id%type -- return new account id
    );
  procedure make_payment (
    i_account_id account_balance.account_id%type,
    i_amount account_balance.balance%type,
    i_commit number default gl_commit_yes
    );
  procedure make_charge (
    i_account_id account_balance.account_id%type,
    i_amount account_balance.balance%type,
    i_commit number default gl_commit_yes
    );
  procedure get_account_balance (
    i_account_id in  account_balance.account_id%type     
   ,i_date       in  date default null
   ,o_balance    out account_balance.balance%type    
    );
  procedure get_credit_flow (
    i_account_id in  account_balance.account_id%type
   ,i_start_time in  charge.charge_date%type
   ,i_end_time   in  charge.charge_date%type
   ,o_sum        out charge.amount%type
   );    
  procedure get_debet_flow (
    i_account_id in  account_balance.account_id%type
   ,i_start_time in  payment.pay_date%type
   ,i_end_time   in  payment.pay_date%type
   ,o_sum        out payment.amount%type
   );        
  procedure get_interest (
    i_account_id    in  account_balance.account_id%type
   ,i_start_date    in  date
   ,i_end_date      in  date
   ,i_interest_rate in  number
   ,o_sum           out charge.amount%type
   );    
  procedure put_error_message (
    i_msg                    in varchar2 default null,
    i_format_error_stack     in varchar2 default dbms_utility.format_error_stack,
    i_format_call_stack      in varchar2 default dbms_utility.format_call_stack,
    i_format_error_backtrace in varchar2 default dbms_utility.format_error_backtrace
    );
end;
/
