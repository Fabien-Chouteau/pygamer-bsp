with Cortex_M.Systick;

with System.Machine_Code; use System.Machine_Code;

package body PyGamer.Time is

   package Systick renames Cortex_M.Systick;

   Clock_Ms  : Time_Ms := 0 with Volatile;
   Period_Ms : constant Time_Ms := 1;

   Subscribers : array (1 .. 10) of Tick_Callback := (others => null);

   procedure Initialize;
   procedure SysTick_Handler;
   pragma Export (C, SysTick_Handler, "__gnat_sys_tick_trap");

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize is
      Reload : constant := 120_000_000 / 1_000;
   begin

      --  Configure for 1kH tick
      Systick.Configure (Source             => Systick.CPU_Clock,
                         Generate_Interrupt => True,
                         Reload_Value       => Reload);

      Systick.Enable;
   end Initialize;

   ---------------------
   -- SysTick_Handler --
   ---------------------

   procedure SysTick_Handler is
   begin
      Clock_Ms := Clock_Ms + Period_Ms;

      for Subs of Subscribers loop

         if Subs /= null then
            --  Call the subscriber
            Subs.all;
         end if;

      end loop;
   end SysTick_Handler;

   -----------
   -- Clock --
   -----------

   function Clock return Time_Ms
   is (Clock_Ms);

   --------------
   -- Delay_Ms --
   --------------

   procedure Delay_Ms (Milliseconds : UInt64) is
   begin
      Delay_Until (Clock + Milliseconds);
   end Delay_Ms;

   -----------------
   -- Delay_Until --
   -----------------

   procedure Delay_Until (Wakeup_Time : Time_Ms) is
   begin
      while Wakeup_Time > Clock loop
         Asm (Template => "wfi", -- Wait for interrupt
              Volatile => True);
      end loop;
   end Delay_Until;

   -----------------
   -- Tick_Period --
   -----------------

   function Tick_Period return Time_Ms is
   begin
      return Period_Ms;
   end Tick_Period;

   ---------------------
   -- Tick_Subscriber --
   ---------------------

   function Tick_Subscriber (Callback : not null Tick_Callback) return Boolean
   is
   begin
      for Subs of Subscribers loop
         if Subs = Callback then
            return True;
         end if;
      end loop;
      return False;
   end Tick_Subscriber;

   --------------------
   -- Tick_Subscribe --
   --------------------

   function Tick_Subscribe (Callback : not null Tick_Callback) return Boolean
   is
   begin
      for Subs of Subscribers loop
         if Subs = null then
            Subs := Callback;
            return True;
         end if;
      end loop;

      return False;
   end Tick_Subscribe;

   ----------------------
   -- Tick_Unsubscribe --
   ----------------------

   function Tick_Unsubscribe (Callback : not null Tick_Callback) return Boolean
   is
   begin
      for Subs of Subscribers loop
         if Subs = Callback then
            Subs := null;
            return True;
         end if;
      end loop;
      return False;
   end Tick_Unsubscribe;

   ---------------
   -- HAL_Delay --
   ---------------

   Delay_Instance : aliased PG_Delays;

   function HAL_Delay return not null HAL.Time.Any_Delays is
   begin
      return Delay_Instance'Access;
   end HAL_Delay;

   ------------------------
   -- Delay_Microseconds --
   ------------------------

   overriding
   procedure Delay_Microseconds
     (This : in out PG_Delays;
      Us   :        Integer)
   is
      pragma Unreferenced (This);
   begin
      Delay_Ms (UInt64 (Us / 1000));
   end Delay_Microseconds;

   ------------------------
   -- Delay_Milliseconds --
   ------------------------

   overriding
   procedure Delay_Milliseconds
     (This : in out PG_Delays;
      Ms   :        Integer)
   is
      pragma Unreferenced (This);
   begin
      Delay_Ms (UInt64 (Ms));
   end Delay_Milliseconds;

   -------------------
   -- Delay_Seconds --
   -------------------

   overriding
   procedure Delay_Seconds (This : in out PG_Delays;
                            S    :        Integer)
   is
      pragma Unreferenced (This);
   begin
      Delay_Ms (UInt64 (S * 1000));
   end Delay_Seconds;

begin
   Initialize;
end PyGamer.Time;
