-- ============================================================
-- create_cust_last.sql - manual fix for HammerDB 6.0 build issue
-- Symptom: buildschema fails at stored procedures on SQL Server
--   2008 R2 AND 2014 SP1:
--   "Incorrect syntax near the keyword 'OR'."
--   "'CREATE/ALTER PROCEDURE' must be the first statement in a
--    query batch."
-- Result: only 5 of 6 TPC-C procs exist - CUST_LAST is missing.
-- Data is intact; do NOT delete/rebuild the schema.
-- Run against the tpcc database:
--   sqlcmd -S <server> -U sa -P <pass> -d tpcc -i create_cust_last.sql
-- Verify:
--   EXEC dbo.CUST_LAST @w_id=1, @d_id=1, @c_id=@cid OUTPUT,
--                      @c_last=@cl OUTPUT;  -- with a real last name
-- ============================================================
IF OBJECT_ID('dbo.CUST_LAST','P') IS NOT NULL DROP PROCEDURE dbo.CUST_LAST;
GO
CREATE PROCEDURE dbo.CUST_LAST
@w_id INT, @d_id INT, @c_id INT OUTPUT, @c_last VARCHAR(16) OUTPUT
AS
BEGIN
    DECLARE @c_balance FLOAT, @c_first VARCHAR(16), @c_middle VARCHAR(2), @c_last_out VARCHAR(16)
    DECLARE @counter INT = 0, @target INT = 0
    DECLARE c_cust CURSOR FOR
    SELECT c_id, c_balance, c_first, c_middle, c_last FROM customer
    WHERE c_w_id = @w_id AND c_d_id = @d_id AND c_last = @c_last ORDER BY c_first
    OPEN c_cust
    FETCH c_cust INTO @c_id, @c_balance, @c_first, @c_middle, @c_last_out
    WHILE (@@FETCH_STATUS = 0) BEGIN SET @counter = @counter + 1
        FETCH c_cust INTO @c_id, @c_balance, @c_first, @c_middle, @c_last_out END
    CLOSE c_cust
    SET @target = CAST((@counter + 1) / 2 AS INT)
    SET @counter = 0
    OPEN c_cust
    FETCH c_cust INTO @c_id, @c_balance, @c_first, @c_middle, @c_last_out
    WHILE (@@FETCH_STATUS = 0) BEGIN SET @counter = @counter + 1
        IF (@counter = @target) BEGIN SET @c_last = @c_last_out; BREAK END
        FETCH c_cust INTO @c_id, @c_balance, @c_first, @c_middle, @c_last_out END
    CLOSE c_cust; DEALLOCATE c_cust
END
GO
