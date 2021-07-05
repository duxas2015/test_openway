create or replace package pkg_test_account_operation is

  procedure clear_data;
  procedure set_fixed_date ( i_date date default null );

end pkg_test_account_operation;
/
