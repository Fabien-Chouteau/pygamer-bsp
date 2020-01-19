with HAL;      use HAL;
with HAL.GPIO;


with SAM.Device;
with SAM.Port;
with SAM.ADC;
with SAM.Clock_Generator;
with SAM.Clock_Generator.IDs;
with SAM.Main_Clock;
with SAM.Functions;


package body PyGamer.Controls is

   type Buttons_State is array (Buttons) of Boolean;

   Current_Pressed : Buttons_State := (others => False);
   Previous_Pressed : Buttons_State := (others => False);

   Clk   : SAM.Port.GPIO_Point renames SAM.Device.PB31;
   Latch : SAM.Port.GPIO_Point renames SAM.Device.PB00;
   Input : SAM.Port.GPIO_Point renames SAM.Device.PB30;

   Joy_X : SAM.Port.GPIO_Point renames SAM.Device.PB07;
   Joy_Y : SAM.Port.GPIO_Point renames SAM.Device.PB06;

   Joy_X_AIN : constant SAM.ADC.Positive_Selection := SAM.ADC.AIN9;
   Joy_Y_AIN : constant SAM.ADC.Positive_Selection := SAM.ADC.AIN8;

   Joy_X_Last : Joystick_Range := 0;
   Joy_Y_Last : Joystick_Range := 0;

   Joystick_Threshold : constant := 64;

   ADC   : SAM.ADC.ADC_Device renames SAM.Device.ADC1;

   procedure Initialize;
   function Read_ADC (AIN : SAM.ADC.Positive_Selection) return Joystick_Range;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize is
   begin

      -- Buttons --
      Clk.Clear;
      Clk.Set_Mode (HAL.GPIO.Output);

      Latch.Clear;
      Latch.Set_Mode (HAL.GPIO.Output);

      Input.Set_Mode (HAL.GPIO.Input);

      -- Joystick --

      Joy_X.Set_Mode (HAL.GPIO.Input);
      Joy_X.Set_Pull_Resistor (HAL.GPIO.Floating);
      Joy_X.Set_Function (SAM.Functions.PB07_ADC1_AIN9);

      Joy_Y.Set_Mode (HAL.GPIO.Input);
      Joy_Y.Set_Pull_Resistor (HAL.GPIO.Floating);
      Joy_Y.Set_Function (SAM.Functions.PB06_ADC1_AIN8);

      SAM.Clock_Generator.Configure_Periph_Channel
        (SAM.Clock_Generator.IDs.ADC1, Clk_48Mhz);

      SAM.Main_Clock.ADC1_On;

      ADC.Configure (Resolution        => SAM.ADC.Res_8bit,
                     Reference         => SAM.ADC.VDDANA,
                     Prescaler         => SAM.ADC.Pre_16,
                     Free_Running      => False,
                     Differential_Mode => False);

   end Initialize;

   --------------
   -- Read_ADC --
   --------------

   function Read_ADC (AIN : SAM.ADC.Positive_Selection) return Joystick_Range is
      Result : UInt16;
   begin
      ADC.Enable;

      ADC.Set_Inputs (SAM.ADC.GND, AIN);

      --  Read twice and disacard the first value.
      --  See AT11481: ADC Configurations with Examples:
      --  "Discard the first conversion result whenever there is a change in ADC
      --  configuration like voltage reference / ADC channel change"
      for X in 1 .. 2 loop
         ADC.Software_Start;

         while not ADC.Conversion_Done loop
            null;
         end loop;

         Result := ADC.Result;
      end loop;

      ADC.Disable;

      return Joystick_Range (Integer (Result) - 128);
   end Read_ADC;

   ----------
   -- Scan --
   ----------

   procedure Scan is
      type IO_Count is range 0 .. 7;
      State : array (IO_Count) of Boolean;
   begin

      -- Buttons --

      Previous_Pressed := Current_Pressed;

      --  Set initial clock state
      Clk.Set;

      --  Load the inputs
      Latch.Clear;
      Latch.Set;

      for X in IO_Count loop
         Clk.Clear;

         State (X) := Input.Set;

         Clk.Set;
      end loop;

      Current_Pressed (B) := State (0);
      Current_Pressed (A) := State (1);
      Current_Pressed (Start) := State (2);
      Current_Pressed (Sel) := State (3);

      -- Joystick --

      Joy_X_Last := Read_ADC (Joy_X_AIN);
      Joy_Y_Last := Read_ADC (Joy_Y_AIN);

      if (abs Integer (Joy_X_Last)) < Joystick_Threshold then
         Current_Pressed (Left) := False;
         Current_Pressed (Right) := False;
      elsif Joy_X_Last > 0 then
         Current_Pressed (Left) := False;
         Current_Pressed (Right) := True;
      else
         Current_Pressed (Left) := True;
         Current_Pressed (Right) := False;
      end if;

      if (abs Integer (Joy_Y_Last)) < Joystick_Threshold then
         Current_Pressed (Up) := False;
         Current_Pressed (Down) := False;
      elsif Joy_Y_Last > 0 then
         Current_Pressed (Up) := False;
         Current_Pressed (Down) := True;
      else
         Current_Pressed (Up) := True;
         Current_Pressed (Down) := False;
      end if;
   end Scan;

   -------------
   -- Pressed --
   -------------

   function Pressed (Button : Buttons) return Boolean
   is (Current_Pressed (Button));

   ------------
   -- Rising --
   ------------

   function Rising  (Button : Buttons) return Boolean
   is (Previous_Pressed (Button) and then not Current_Pressed (Button));

   -------------
   -- Falling --
   -------------

   function Falling (Button : Buttons) return Boolean
   is (not Previous_Pressed (Button) and then Current_Pressed (Button));

   ----------------
   -- Joystick_X --
   ----------------

   function Joystick_X return Joystick_Range
   is (Joy_X_Last);

   ----------------
   -- Joystick_Y --
   ----------------

   function Joystick_Y return Joystick_Range
   is (Joy_Y_Last);

begin
   Initialize;
end PyGamer.Controls;
