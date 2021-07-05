create or replace package body pkg_account_operation is

  /* Create a new account with a predefined amount of money on its balance if provided */
  procedure create_account (
    i_init_balance in  account_balance.balance%type default 0, -- initial balance if present
    i_commit       in  number default gl_commit_yes, -- commit management: 1 - inside current procedure; 0 - outside current procedure
    o_account_id   out account_balance.account_id%type -- return new account id

    ) is
      v_init_balance number := nvl( i_init_balance, 0 ); -- defence against NULL value passed explicitely
      v_commit number := nvl( i_commit, 1 );
      v_sysdate date := sysdate;
      ex_init_balance_negative exception;
    begin
      if ( i_init_balance < 0 ) then
        raise ex_init_balance_negative;
      end if;  

      insert into account_balance ( account_id, balance ) values ( account_seq.nextval, v_init_balance ) returning account_id into o_account_id;
      insert into account_balance_history (account_id, balance, start_time, end_time )
        values ( o_account_id, i_init_balance, v_sysdate, gl_history_max_date ); 
      
      if ( v_commit = 1 ) then
        commit;
      end if;
    exception
      when ex_init_balance_negative then
        put_error_message ( 
          i_msg => 'Initial balance is negative. It should be zero or positive.'
          );
        raise;  
      when others then
        put_error_message();
        if ( v_commit = 1 ) then
          rollback;
        end if;
        raise;
    end;

  /* make an operation with the balance of a defined account */
  procedure account_balance_operation (
    i_account_id account_balance.account_id%type
   ,i_amount     account_balance.balance%type
   ,i_date       date
   ,i_commit     number default 1
    ) is
      v_commit number := nvl( i_commit, 1 );
      v_old_balance account_balance.balance%type;
      v_new_balance account_balance.balance%type;
      v_old_start_time account_balance_history.start_time%type;
      ex_no_account_found exception;
      ex_balance_negative exception;
    begin
      begin
        select balance 
          into v_old_balance
        from account_balance 
          where account_id = i_account_id 
          for update; -- lock the account balance from other sessions until commit
      exception 
        when no_data_found then
          raise ex_no_account_found;
      end; 
      
      v_new_balance := v_old_balance + i_amount;
      
      if ( v_new_balance < 0 ) then
        raise ex_balance_negative;
      end if;  
      
      update account_balance set balance = v_new_balance where account_id = i_account_id;

      select start_time
        into v_old_start_time
      from account_balance_history
        where    account_id = i_account_id 
             and start_time <= i_date and end_time = gl_history_max_date;

      if ( i_date = v_old_start_time ) then -- if there are several operation at the same second
        update account_balance_history
          set balance = v_new_balance
        where     account_id = i_account_id
              and start_time <= i_date and end_time = gl_history_max_date;
      else
        
        -- this way of updating history tables is preferable in case we deal with the tables parititioned by end_time column. 
        -- The last history record ( read: the actual one ) always stays in the same partition. No need to enable row movement. And you have a good opportunity to clear obsolete history data just truncating old partitions.
        -- I don't use partitional tables in my mock snippet but I'am trying to make easy-portable code.

        update account_balance_history
          set balance = v_new_balance, start_time = i_date
        where     account_id = i_account_id
              and start_time <= i_date and end_time = gl_history_max_date;

        insert into account_balance_history (account_id, balance, start_time, end_time )
          values ( i_account_id, v_old_balance, v_old_start_time, i_date );
          
      end if;    
      
      if ( v_commit = 1 ) then
        commit;
      end if;
    exception
      when ex_no_account_found then
        put_error_message(
          i_msg => 'Account ' || i_account_id || 'doesn''t exist.'
          );
        if ( v_commit = 1 ) then
          rollback;
        end if;
        raise;  
      when ex_balance_negative then
        put_error_message(
          i_msg => 'You''re trying set a negative balance. It''s forbidden.'
          );
        if ( v_commit = 1 ) then
          rollback;
        end if;
        raise;  
      when others then
        put_error_message();
        if ( v_commit = 1 ) then
          rollback;
        end if;
        raise;  
    end;

  /* make a payment with a defined account */
  procedure make_payment (
    i_account_id account_balance.account_id%type
    ,i_amount account_balance.balance%type
    ,i_commit number default gl_commit_yes    
    ) is
      ex_amount_is_not_positive exception;
      v_sysdate date := sysdate;
      v_commit number := nvl ( i_commit, gl_commit_yes );
      ex_parent_key_not_found    exception;
      pragma exception_init ( ex_parent_key_not_found, -2291 );
    begin
      if ( i_amount <= 0 ) then
        raise ex_amount_is_not_positive;
      end if;
      
      insert into payment ( pay_id, account_id, pay_date, amount ) 
        values ( payment_seq.nextval, i_account_id, v_sysdate, i_amount );
      
      account_balance_operation (
        i_account_id => i_account_id
       ,i_amount => i_amount
       ,i_date   => v_sysdate
       ,i_commit => gl_commit_no
        );

      if ( v_commit = gl_commit_yes ) then
        commit;
      end if;
      
    exception
      when ex_amount_is_not_positive then
        put_error_message(
          i_msg => 'You''re trying  to pay with amount ' || i_account_id || ' , which is negative of zero. It should be positive.'
          );
        raise;  
      when ex_parent_key_not_found then
        put_error_message(
          i_msg => 'You''re trying  to pay with non_existing account_id ' || i_account_id 
          );
        if ( v_commit = gl_commit_yes ) then
          rollback;
        end if;
        raise;  
      when others then
        put_error_message();
        if ( v_commit = gl_commit_yes ) then
          rollback;
        end if;
        raise;  
    end;

  /* make a charge with a defined account */
  procedure make_charge (
    i_account_id account_balance.account_id%type,
    i_amount account_balance.balance%type,
    i_commit number default gl_commit_yes
    ) is
      v_sysdate date := sysdate;
      ex_amount_is_not_positive exception;
      ex_parent_key_not_found    exception;
      pragma exception_init ( ex_parent_key_not_found, -2291 );
      v_commit number := nvl( i_commit, gl_commit_yes );
    begin
      if ( i_amount <= 0 ) then
        raise ex_amount_is_not_positive;
      end if;
      
      insert into charge ( charge_id, account_id, charge_date, amount )
        values ( charge_seq.nextval, i_account_id, v_sysdate, i_amount );
      
      account_balance_operation (
        i_account_id => i_account_id
       ,i_amount => i_amount * (-1)
       ,i_date   => v_sysdate
       ,i_commit => gl_commit_no
        );
        
      if ( v_commit = gl_commit_yes ) then
        commit;
      end if;
        
    exception
      when ex_amount_is_not_positive then
        put_error_message(
          i_msg => 'You''re trying  to charge with amount ' || i_account_id || ' , which is negative of zero. It should be positive.'
          );
        if ( v_commit = gl_commit_yes ) then
          rollback;
        end if;
        raise;  
      when ex_parent_key_not_found then
        put_error_message(
          i_msg => 'You''re trying  to charge with non_existing account_id ' || i_account_id 
          );
        if ( v_commit = gl_commit_yes ) then
          rollback;
        end if;
        raise;  
      when others then
        put_error_message();
        if ( v_commit = gl_commit_yes ) then
          rollback;
        end if;
        raise;  
    end;
    
  /* Get an account balance 
       a. current balance
       b. at defined date if present i_date parameter
  */  
  procedure get_account_balance (
    i_account_id in  account_balance.account_id%type     
   ,i_date       in  date default null
   ,o_balance    out account_balance.balance%type    
    ) is
    ex_account_id_not_present exception;
  begin
   if ( i_account_id is null ) then
     raise ex_account_id_not_present;
   end if; 
    
   if ( i_date is null ) then 
     begin
       select balance
        into o_balance
        from account_balance
        where account_id = i_account_id;
     exception 
       when no_data_found then
         put_error_message (
           i_msg => 'Account ' || i_account_id || ' doesn''t exist'
           );
         raise;  
     end;       
   else -- i_date is defined
     begin
       select balance
         into o_balance
       from account_balance_history
         where     account_id = i_account_id
               and start_time <= i_date and i_date < end_time;
     exception
       when no_data_found then
         put_error_message (
           i_msg => 'There is no data about the balance of the account ' || i_account_id || ' at ' || to_char (i_date,'dd/mm/yyyy hh24:mi:ss')
           );
         raise;  
     end;    
   end if;   
  exception
    when ex_account_id_not_present then
      put_error_message(
        i_msg => 'Account ID isn''t present. Its value is empty ( NULL )'
      );
      raise;
    when others then
      put_error_message();
      raise;
  end;

  /* Get debet flow by account id for defined period */
  procedure get_debet_flow (
    i_account_id in  account_balance.account_id%type
   ,i_start_time in  payment.pay_date%type
   ,i_end_time   in  payment.pay_date%type
   ,o_sum        out payment.amount%type
   ) is
     ex_parameter_not_present exception;
     ex_incorrect_date exception;
  begin
    if (    i_account_id is null
         or i_start_time is null
         or i_end_time is null ) 
    then
      raise ex_parameter_not_present;
    end if;  

    if ( i_start_time >= i_end_time ) then
      raise ex_incorrect_date;
    end if;

    begin
      select sum(amount)
        into o_sum
      from payment
        where     account_id = i_account_id
              and i_start_time < = pay_date and pay_date <= i_end_time;
    exception
      when no_data_found then
        o_sum := 0;
    end;              
  exception 
    when ex_parameter_not_present then
      put_error_message (
        i_msg => 'One or more necessary incoming parameter are not present. Its value is NULL.'
        );
      raise;  
    when ex_incorrect_date then
      put_error_message (
        i_msg => 'The beginning date is equal or more than the ending one.'
        );
      raise;  
    when others then
      put_error_message();
      raise;  
  end;  

  /* Get credit flow by account id for defined period */
  procedure get_credit_flow (
    i_account_id in  account_balance.account_id%type
   ,i_start_time in  charge.charge_date%type
   ,i_end_time   in  charge.charge_date%type
   ,o_sum        out charge.amount%type
   ) is
     ex_parameter_not_present exception;
     ex_incorrect_dates exception;
  begin
    if (    i_account_id is null
         or i_start_time is null
         or i_end_time is null ) 
    then
      raise ex_parameter_not_present;
    end if;  

    if ( i_start_time >= i_end_time ) then
      raise ex_incorrect_dates;
    end if;

    begin
      select sum(amount)
        into o_sum
      from charge
        where     account_id = i_account_id
              and i_start_time < = charge_date and charge_date <= i_end_time;
    exception
      when no_data_found then
        o_sum := 0;
    end;              
  exception 
    when ex_parameter_not_present then
      put_error_message (
        i_msg => 'One or more necessary incoming parameter are not present. Its value is NULL.'
        );
      raise;  
    when ex_incorrect_dates then
      put_error_message (
        i_msg => 'The beginning date is equal or more than the ending one.'
        );
      raise;  
    when others then
      put_error_message();
      raise;  
  end;  

  /* Get the interest of an account for period with a defined rate */
  procedure get_interest (
    i_account_id    in  account_balance.account_id%type
   ,i_start_date    in  date
   ,i_end_date      in  date
   ,i_interest_rate in  number
   ,o_sum           out charge.amount%type
   ) is
     ex_incorrect_date exception;
     ex_parameter_not_present exception;
     ex_date_not_round exception;
     ex_interest_rate_is_negative exception;
     ex_no_account_data_in_period exception;
     type t_balance_period_rec is record ( 
       start_time account_balance_history.start_time%type, 
       end_time account_balance_history.end_time%type, 
       balance account_balance_history.balance%type,
       first_record_wi_day number(1),
       last_record_wi_day number(1)
       );
     type t_balance_period_tbl is table of t_balance_period_rec;
     v_balance_period_tb t_balance_period_tbl;

     type t_balance_interest_period_rec is record ( 
       start_date date, 
       end_date date, 
       balance account_balance_history.balance%type 
       );
     type t_balance_interest_period_tbl is table of t_balance_interest_period_rec;
     v_balance_interest_period_tb t_balance_interest_period_tbl := t_balance_interest_period_tbl();
     
     v_balance number;
     v_day_amount number;
     v_day_in_year number; -- a number of days in a year under consideration
     v_interest_period_start_date date;
     v_interest_period_end_date date;
     v_interest_balance number;
     v_idx number;
     vf_next_day number := 0;
     v_current_interest number;
     
     procedure append_interest_period (
       i_interest_period_start_date in date,
       i_interest_period_end_date in date,
       i_interest_period_balance in number,
       io_balance_interest_period_tb in out t_balance_interest_period_tbl
       ) is
     begin
        io_balance_interest_period_tb.extend;
        io_balance_interest_period_tb(io_balance_interest_period_tb.last).start_date := i_interest_period_start_date;
        io_balance_interest_period_tb(io_balance_interest_period_tb.last).end_date := i_interest_period_end_date;
        io_balance_interest_period_tb(io_balance_interest_period_tb.last).balance := i_interest_period_balance;
     end append_interest_period;
     
  begin
    if (    i_account_id is null
         or i_start_date is null
         or i_end_date is null 
         or i_interest_rate is null ) 
    then
      raise ex_parameter_not_present;
    end if;  
    
    if (    i_start_date <> trunc( i_start_date )
         or i_end_date <> trunc( i_end_date) 
       )
    then
      raise ex_date_not_round;
    end if;
    
    if ( i_start_date >= i_end_date ) then
      raise ex_incorrect_date;
    end if;
    
    if ( i_interest_rate < 0 ) then
      raise ex_interest_rate_is_negative;
    end if;
    
    select
      start_time,
      end_time,
      balance,
      decode(start_time,first_start_time_wi_day,1,0) first_record_wi_day,
      decode(start_time,last_start_time_wi_day,1,0) last_record_wi_day
    bulk collect into v_balance_period_tb                     
    from 
      (
        select start_time, 
               end_time, 
               balance,
               min ( start_time ) over ( partition by trunc( start_time ) ) first_start_time_wi_day,
               max ( start_time ) over ( partition by trunc( start_time ) ) last_start_time_wi_day
        from account_balance_history
          where     account_id = i_account_id
                and start_time < i_end_date
                and end_time > i_start_date
        order by start_time
      );    
    
    if ( v_balance_period_tb.count = 0 ) then
      raise ex_no_account_data_in_period;
    end if;
    
    v_interest_period_end_date := i_start_date;
    v_idx := 1;

    loop  

      if (     v_balance_period_tb(v_idx).first_record_wi_day = 1
           and v_balance_period_tb(v_idx).last_record_wi_day = 1
         ) -- we have only one record within a day
      then

        v_interest_period_start_date := v_interest_period_end_date;
        v_interest_period_end_date := trunc( v_interest_period_start_date ) + 1;
        v_balance := nvl( v_balance, v_balance_period_tb(v_idx).balance ); -- nvl , in case we have the first record in the whole set, and the previous balance is not set
        
        append_interest_period( 
          i_interest_period_start_date => v_interest_period_start_date,
          i_interest_period_end_date => v_interest_period_end_date,
          i_interest_period_balance => v_balance,
          io_balance_interest_period_tb => v_balance_interest_period_tb
          );

        v_interest_period_start_date := v_interest_period_end_date;
        v_balance := v_balance_period_tb(v_idx).balance;
        v_interest_period_end_date := least ( trunc( v_balance_period_tb(v_idx).end_time ), i_end_date ); 
        
      elsif (     v_balance_period_tb(v_idx).first_record_wi_day = 1
              and  v_balance_period_tb(v_idx).last_record_wi_day = 0
            ) -- we have the first record within a day
      then
        
        v_interest_period_start_date := v_interest_period_end_date;
        v_balance := nvl( v_balance, v_balance_period_tb(v_idx).balance );
        v_idx := v_idx + 1;
        continue;
      
      elsif (     v_balance_period_tb(v_idx).first_record_wi_day = 0
              and  v_balance_period_tb(v_idx).last_record_wi_day = 1
            ) -- we have the last record within a day
      then      

        v_interest_period_end_date := trunc( v_interest_period_start_date ) + 1;
        
        append_interest_period( 
          i_interest_period_start_date => v_interest_period_start_date,
          i_interest_period_end_date => v_interest_period_end_date,
          i_interest_period_balance => v_balance,
          io_balance_interest_period_tb => v_balance_interest_period_tb
          );

        v_interest_period_start_date := v_interest_period_end_date;
        v_balance := v_balance_period_tb(v_idx).balance;
        v_interest_period_end_date := least ( trunc( v_balance_period_tb(v_idx).end_time ), i_end_date ); 

      else -- we have an intermediate record within a day
        -- pay no attention , go the next record
        v_idx := v_idx + 1;
        continue;  
      end if;       

      if ( trunc(v_interest_period_start_date, 'yyyy') <> trunc(v_interest_period_end_date,'yyyy') ) then
        -- if period passes by New Years, divide it by years
        declare
          v_local_intrst_prd_start_date date;
          v_local_intrst_prd_end_date date := v_interest_period_start_date;
        begin
          loop
            v_local_intrst_prd_start_date := v_local_intrst_prd_end_date;
            v_local_intrst_prd_end_date := least ( add_months(trunc(v_local_intrst_prd_start_date,'yyyy'),12), v_interest_period_end_date );

            append_interest_period( 
              i_interest_period_start_date => v_local_intrst_prd_start_date,
              i_interest_period_end_date => v_local_intrst_prd_end_date,
              i_interest_period_balance => v_balance,
              io_balance_interest_period_tb => v_balance_interest_period_tb
              );

            exit when v_local_intrst_prd_end_date = v_interest_period_end_date;            
          end loop;  
        end;

      else
        
        append_interest_period( 
          i_interest_period_start_date => v_interest_period_start_date,
          i_interest_period_end_date => v_interest_period_end_date,
          i_interest_period_balance => v_balance,
          io_balance_interest_period_tb => v_balance_interest_period_tb
          );
      
      end if;  

      v_idx := v_idx + 1;
      exit when v_idx > v_balance_period_tb.count;          
      
    end loop;  
    
    o_sum := 0;
    
    -- get interest by all the interest periods    
    for v_idx in nvl(v_balance_interest_period_tb.first, 0) .. nvl(v_balance_interest_period_tb.last,-1) loop

      if ( to_number(to_char( v_balance_interest_period_tb(v_idx).start_date, 'yyyy' )) mod 4 = 0 ) then -- leap year has 366 day
        v_day_in_year := 366;
      else
        v_day_in_year := 365;
      end if ;
      
      v_interest_balance := v_balance_interest_period_tb(v_idx).balance;
      
      v_day_amount := v_balance_interest_period_tb(v_idx).end_date - v_balance_interest_period_tb(v_idx).start_date;
      
      v_current_interest := round ( v_interest_balance * i_interest_rate * ( v_day_amount / v_day_in_year ), 2 );
      o_sum := o_sum + v_current_interest; 
      
      dbms_output.put_line ( 
         to_char ( v_balance_interest_period_tb(v_idx).start_date, 'dd.mm.yyyy') || ' - ' 
      || to_char ( v_balance_interest_period_tb(v_idx).end_date, 'dd.mm.yyyy') 
      || ' balance : ' || v_balance_interest_period_tb(v_idx).balance
      || ' interest : ' || v_current_interest
      );

    end loop;      
  exception
    when ex_incorrect_date then
      put_error_message(
        i_msg => 'Incorrect start or end date of period.'
        );
      raise;
    when ex_parameter_not_present then
      put_error_message(
        i_msg => 'One or more parameters are not present.'
        );
      raise;
    when ex_date_not_round then 
      put_error_message(
        i_msg => 'The period dates provided are not round.'
        );
      raise;
    when ex_interest_rate_is_negative then
      put_error_message(
        i_msg => 'The interest rate is negative or zero.'
        );
      raise;
    when ex_no_account_data_in_period then
      put_error_message(
        i_msg => 'No any account balance data for the period provided.'
        );
      raise;
    when others then
      put_error_message();
      raise;
  end get_interest;     

  /* Put a error message into error log table */
  procedure put_error_message (
    i_msg                    in varchar2 default null,
    i_format_error_stack     in varchar2 default dbms_utility.format_error_stack,
    i_format_call_stack      in varchar2 default dbms_utility.format_call_stack,
    i_format_error_backtrace in varchar2 default dbms_utility.format_error_backtrace
    ) is
      pragma autonomous_transaction;
  begin
    -- Here should be some code saving the current error in error_log. I think the implementation of this code is irrelevant right now.
    -- Like this :
    -- insert into error_log () values ();
    -- commit;
    null;
  end;

begin
  null;
end;
/
