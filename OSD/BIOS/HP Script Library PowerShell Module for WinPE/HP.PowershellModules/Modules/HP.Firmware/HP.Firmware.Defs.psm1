#
#  Copyright 2018-2021 HP Development Company, L.P.
#  All Rights Reserved.
#
# NOTICE:  All information contained herein is, and remains the property of HP Development Company, L.P.
#
# The intellectual and technical concepts contained herein are proprietary to HP Development Company, L.P
# and may be covered by U.S. and Foreign Patents, patents in process, and are protected by
# trade secret or copyright law. Dissemination of this information or reproduction of this material
# is strictly forbidden unless prior written permission is obtained from HP Development Company, L.P.


Set-StrictMode -Version 3.0
$env:PATH += ";$PSScriptRoot"
Add-Type -TypeDefinition @'
    using System;
    using System.IO;
    using System.Collections.Generic;
    using System.Runtime.InteropServices;
    using System.Windows.Forms;

//  HP SUREVIEW
public enum sureview_status_t : byte {
    sureview_off = 0xff,
    sureview_on = 0xfe,
    sureview_forced_on = 0xfc,
    sureview_unsupported = 0xfa,
    sureview_unknown = 0
};

[Flags]
public enum sureview_capabilities_t : byte{
    touch_ui = 0x01
};


public enum  sureview_desired_state_t : byte {
    sureview_desired_off = 0,
    sureview_desired_on = 1,
    sureview_desired_on_max = 2
} ;


[StructLayout(LayoutKind.Sequential, Pack = 1)]
public struct sureview_state_t
{
     [MarshalAs(UnmanagedType.U1)] public sureview_status_t status; // of type sureview_status_t
     [MarshalAs(UnmanagedType.U1)] public  byte visibility;
     [MarshalAs(UnmanagedType.U1)] public  sureview_capabilities_t capabilities; // of type sureview_capabilities_t
};


public  static  class DfmNativeSureView
{
    [DllImport("dfmbios32.dll", EntryPoint = "get_sureview_state", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
    public static extern int get_sureview_state32([In,Out] ref sureview_state_t data, [In,Out] ref int extended_result);
    [DllImport("dfmbios64.dll", EntryPoint = "get_sureview_state", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
    public static extern int get_sureview_state64([In,Out] ref sureview_state_t data, [In,Out] ref int extended_result);

    [DllImport("dfmbios32.dll", EntryPoint = "set_sureview_state", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
    public static extern int set_sureview_state32([In] sureview_desired_state_t on, [In] byte visibility, [In,Out] ref int extended_result);
    [DllImport("dfmbios64.dll", EntryPoint = "set_sureview_state", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
    public static extern int set_sureview_state64([In] sureview_desired_state_t on, [In] byte visibility, [In,Out] ref int extended_result);
 }

// GENERAL FIRMWARE
[StructLayout(LayoutKind.Sequential, Pack = 1)]
public struct opaque4096_t
{
        [MarshalAs(UnmanagedType.ByValArray, ArraySubType = UnmanagedType.I1, SizeConst = 4096)]  public byte[] raw;
};

public enum authentication_t : uint
{
    auth_t_anonymous = 0,
    auth_t_password = 1,
    auth_t_beam = 2
}
[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode, Pack = 1)]
public struct authentication_data_t {
    [MarshalAs(UnmanagedType.U2)] public ushort password_size;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string password;

};
[StructLayout(LayoutKind.Sequential, Pack = 1)]
public struct bios_credential_t
{
    [MarshalAs(UnmanagedType.U4)] public authentication_t authentication;
    [MarshalAs(UnmanagedType.Struct)] public authentication_data_t data;
}

[UnmanagedFunctionPointer(CallingConvention.StdCall)]
public delegate void ProgressCallback(UInt32 location, UInt32 value1, UInt32 value2, UInt32 state);


 //  AUDIT LOG and LOGO

   public enum audit_log_severity_t : uint
    {
        logged_severity_reserved = 0,
        logged_severity_unknown = 1,
        logged_severity_normal = 2,
        logged_severity_low = 3,
        logged_severity_medium = 4,
        logged_severity_high = 5,
        logged_severity_critical = 6,
    }


    public enum powerstate_t : uint
    {
        S0 = 0,
        S3 = 1,
        S4S5 = 2,
        RESERVED = 3
    }
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    public struct timestamp_t
    {
        public Int16 year;
        public Int16 month;
        public Int16 day_of_week;
        public Int16 day;
        public Int16 hour;
        public Int16 minute;
        public Int16 second;
        public Int16 millisecond;
    }
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    public struct bios_log_entry_t
    {
        [MarshalAs(UnmanagedType.U1)] public byte status;
        [MarshalAs(UnmanagedType.U4)] public UInt32 message_number;
        [MarshalAs(UnmanagedType.Struct)] public  timestamp_t timestamp;
        [MarshalAs(UnmanagedType.U4)] public UInt32 timestamp_is_exact;
        [MarshalAs(UnmanagedType.U4)] public powerstate_t system_state_at_event;
        [MarshalAs(UnmanagedType.U4)] public UInt32 source_id;
        [MarshalAs(UnmanagedType.U4)] public UInt32 event_id;
        [MarshalAs(UnmanagedType.U4)] public audit_log_severity_t severity;
        [MarshalAs(UnmanagedType.U1)] public byte data_0;
        [MarshalAs(UnmanagedType.U1)] public byte data_1;
        [MarshalAs(UnmanagedType.U1)] public byte data_2;
        [MarshalAs(UnmanagedType.U1)] public byte data_3;
        [MarshalAs(UnmanagedType.U1)] public byte data_4;
    }

    public  static  class DfmNativeBios
    {
        [DllImport("dfmbios32.dll", EntryPoint = "get_audit_logs", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
        public static extern UInt32 get_audit_logs_32([Out] bios_log_entry_t[] results, [In,Out] ref UInt32 buffer_size, [In,Out] ref UInt32 records_count, [Out] out UInt32 extended_result);
        [DllImport("dfmbios64.dll", EntryPoint = "get_audit_logs", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
        public static extern UInt32 get_audit_logs_64([Out] bios_log_entry_t[] results, [In,Out] ref UInt32 buffer_size, [In,Out] ref UInt32 records_count, [Out] out UInt32 extended_result);
        [DllImport("dfmbios32.dll", EntryPoint = "query_enterprise_logo", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
        public static extern Int32 query_enterprise_logo32([Out] out UInt32 installed, [Out] out UInt32 state, [Out] out UInt32 extended_result);
        [DllImport("dfmbios64.dll", EntryPoint = "query_enterprise_logo", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
        public static extern Int32 query_enterprise_logo64([Out] out UInt32 installed, [Out] out UInt32 state, [Out] out UInt32 extended_result);
        [DllImport("dfmbios32.dll", EntryPoint = "set_enterprise_logo", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
        public static extern Int32 set_enterprise_logo32([In] string filename, [In] ref bios_credential_t credentials, [Out] out UInt32 extended_result);
        [DllImport("dfmbios64.dll", EntryPoint = "set_enterprise_logo", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
        public static extern Int32 set_enterprise_logo64([In] string filename, [In] ref bios_credential_t credentials, [Out] out UInt32 extended_result);


        [DllImport("dfmbios32.dll", EntryPoint = "clear_enterprise_logo", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
        public static extern Int32 clear_enterprise_logo32([In] ref bios_credential_t credentials, [Out] out UInt32 extended_result);
        [DllImport("dfmbios64.dll", EntryPoint = "clear_enterprise_logo", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
        public static extern Int32 clear_enterprise_logo64([In] ref bios_credential_t credentials, [Out] out UInt32 extended_result);

        [DllImport("dfmbios64.dll", EntryPoint = "flash_hp_device", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
        public static extern Int32 flash_hp_device64([In] string firmware_file, [In] ref bios_credential_t credentials, [Out] out UInt32 mi_result, [MarshalAs(UnmanagedType.FunctionPtr)]  ProgressCallback callback, [In] string filename_hint, [In] string efi_path, [In] byte[] authorization, [In] UInt32 auth_len);
        [DllImport("dfmbios32.dll", EntryPoint = "flash_hp_device", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
        public static extern Int32 flash_hp_device32([In] string firmware_file, [In] ref bios_credential_t credentials, [Out] out UInt32 mi_result,[MarshalAs(UnmanagedType.FunctionPtr)]   ProgressCallback callback, [In] string filename_hint, [In] string efi_path, [In] byte[] authorization, [In] UInt32 auth_len);

        [DllImport("dfmbios64.dll", EntryPoint = "write_authorization_to_file", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
        public static extern Int32 write_authorization_to_file64([In] byte[] authorization, [In] UInt32 auth_len, [In] string efi_path);
        [DllImport("dfmbios32.dll", EntryPoint = "write_authorization_to_file", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
        public static extern Int32 write_authorization_to_file32([In] byte[] authorization, [In] UInt32 auth_len, [In] string efi_path);

        [DllImport("dfmbios32.dll", EntryPoint = "get_flash_file_information", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
    public static extern UInt32 get_flash_file_information32([In] string firmware_file, [Out] out  UInt32 is_capsule, [Out] out UInt32 is_for_current_platform);
        [DllImport("dfmbios64.dll", EntryPoint = "get_flash_file_information", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
    public static extern UInt32 get_flash_file_information64([In] string firmware_file, [Out] out  UInt32 is_capsule, [Out] out UInt32 is_for_current_platform);

        [DllImport("dfmbios32.dll", EntryPoint = "encrypt_password_to_file", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
    public static extern UInt32 encrypt_password_to_file32([In] ref bios_credential_t credentials, [In] string firmware_file);
        [DllImport("dfmbios64.dll", EntryPoint = "encrypt_password_to_file", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
    public static extern UInt32 encrypt_password_to_file64([In] ref bios_credential_t credentials, [In] string firmware_file);
     }

// HP SECURE PLATFORM

  public enum provisioning_state_t : byte
    {
        NotConfigured = 0,
        Provisioned = 1,
        ProvisioningInProgress = 2
    };

    [Flags]
    public enum secureplatform_features_t : uint
    {
    None = 0,
        SureRun = 1,
        SureRecover = 2,
        Auth = 3,
        SureAdmin = 4
    };

  public struct PortableFileFormat {
    public DateTime timestamp;
    public string purpose;
        public byte[] Data;
        public byte[] Meta1;
        public byte[] Meta2;
        public byte[] Meta3;
        public byte[] Meta4;
  };

    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    public struct provisioning_data_t
    {
        [MarshalAs(UnmanagedType.U1)] public provisioning_state_t state;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst=2)] public byte[] subsystem_version; // major minor
        [MarshalAs(UnmanagedType.U2)] public ushort reserved;
        [MarshalAs(UnmanagedType.U4)] public secureplatform_features_t features_in_use;
        [MarshalAs(UnmanagedType.U4)] public UInt32 arp_counter;
        [MarshalAs(UnmanagedType.ByValArray, ArraySubType = UnmanagedType.I1, SizeConst = 256)]  public byte[] kek_mod;
        [MarshalAs(UnmanagedType.ByValArray, ArraySubType = UnmanagedType.I1, SizeConst = 256)] public byte[] sk_mod;
    };

  [StructLayout(LayoutKind.Sequential, Pack = 1)]
  public struct  sk_provisioning_payload_t {
        [MarshalAs(UnmanagedType.U4)]  public uint counter;
        [MarshalAs(UnmanagedType.ByValArray, ArraySubType = UnmanagedType.I1, SizeConst = 256)]  public byte[] mod;
      } ;



    public  static  class DfmNativeSecurePlatform
    {
        [DllImport("dfmbios32.dll", EntryPoint = "sp_get_provisioning", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
        public static extern int get_secureplatform_provisioning32([In,Out] ref provisioning_data_t data, [In,Out] ref int extended_result);
        [DllImport("dfmbios64.dll", EntryPoint = "sp_get_provisioning", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
        public static extern int get_secureplatform_provisioning64([In,Out] ref provisioning_data_t data, [In,Out] ref int extended_result);

        [DllImport("dfmbios32.dll", EntryPoint = "sp_get_ek_opaque", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
        public static extern int get_ek_provisioning_data32([In] byte[] key, [In] int key_length, [In]  string password, [In]  int password_length,   [In,Out] ref opaque4096_t data, [In,Out] ref int data_len, [In,Out] ref int extended_result);
        [DllImport("dfmbios64.dll", EntryPoint = "sp_get_ek_opaque", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
        public static extern int get_ek_provisioning_data64([In] byte[] key, [In] int key_length, [In]  string password, [In]  int password_length,  [In,Out] ref opaque4096_t data, [In,Out] ref int data_len, [In,Out] ref int extended_result);

        [DllImport("dfmbios32.dll", EntryPoint = "sp_set_ek_opaque", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
        public static extern int set_ek_provisioning32([In] byte[] data, [In] int data_size, [In,Out] ref int extended_result);
        [DllImport("dfmbios64.dll", EntryPoint = "sp_set_ek_opaque", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
        public static extern int set_ek_provisioning64([In] byte[] data, [In] int data_size, [In,Out] ref int extended_result);

        [DllImport("dfmbios32.dll", EntryPoint = "sp_set_sk_opaque", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
        public static extern int set_sk_provisioning32([In] byte[] data, [In] int data_size, [In,Out] ref int extended_result);
        [DllImport("dfmbios64.dll", EntryPoint = "sp_set_sk_opaque", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
        public static extern int set_sk_provisioning64([In] byte[] data, [In] int data_size, [In,Out] ref int extended_result);
    };

    // HP SureRecover

  [StructLayout(LayoutKind.Sequential, Pack = 1)]
  public struct sk_provisioning_t {
    [MarshalAs(UnmanagedType.ByValArray, ArraySubType = UnmanagedType.I1, SizeConst = 256)]  public byte[] sig;
      public sk_provisioning_payload_t data;
  };

  [StructLayout(LayoutKind.Sequential, Pack = 1)]
  public struct surerecover_configuration_t {
    [MarshalAs(UnmanagedType.ByValArray, ArraySubType = UnmanagedType.I1, SizeConst = 256)]  public byte[] sig;
      public surerecover_configuration_payload_t data;
  };

  [StructLayout(LayoutKind.Sequential, Pack = 1)]
  public struct surerecover_configuration_payload_t
  {
    [MarshalAs(UnmanagedType.U4)] public UInt32 arp_counter;
    [MarshalAs(UnmanagedType.U4)] public surerecover_os_flags os_flags;
    [MarshalAs(UnmanagedType.U4)] public surerecover_re_flags re_flags;
  };

  [StructLayout(LayoutKind.Sequential, Pack = 1)]
  public struct surerecover_trigger_t {
    [MarshalAs(UnmanagedType.ByValArray, ArraySubType = UnmanagedType.I1, SizeConst = 256)]  public byte[] sig;
      public surerecover_trigger_payload_t data;
  };

  [StructLayout(LayoutKind.Sequential, Pack = 1)]
  public struct surerecover_trigger_payload_t
  {
    [MarshalAs(UnmanagedType.U4)] public UInt32 arp_counter;
    [MarshalAs(UnmanagedType.U4)] public UInt32 bios_trigger_flags;
    [MarshalAs(UnmanagedType.U4)] public UInt32 re_trigger_flags;
    [MarshalAs(UnmanagedType.ByValArray, ArraySubType = UnmanagedType.I1, SizeConst = 256)]  public byte[] reserved;
  };

    [Flags]
    public enum surerecover_day_of_week : byte
    {
    None = 0,
    Sunday = 1,
    Monday = 2,
        Tuesday = 4,
        Wednesday = 8,
        Thursday = 16,
    Friday = 32,
    Saturday = 64,
    EveryWeek = 128
    };

    [Flags]
    public enum surerecover_os_flags : uint
    {
    None = 0,
    NetworkBasedRecovery = 1,
    WiFi = 2,
        MobileDeviceSupport = 4,
        SecureStorage = 8,
        ATANormalErase = 16,
    ATACryptographicErase = 32,
    RollbackPrevention = 64
    };


  [Flags]
  public enum surerecover_prompt_policy : uint
  {
    None = 0,
    PromptBeforeRecovery = 1,
    PromptOnError = 2,
    PromptAfterRecover = 4
  };

  [Flags]
  public enum surerecover_erase_policy : uint
  {
    None = 0,
    EraseSecureStorage = 16,
    EraseSystemDrives = 32
  };


    [Flags]
    public enum surerecover_re_flags : uint
    {
    None = 0,
    DRDVD = 1,
    Reserved1 = 2,
    Reserved2 = 4,
    Reserved3 = 8,
    Reserved4 = 16,
    Reserved5 = 32,
    RollbackPrevention = 64
    };


   [StructLayout(LayoutKind.Sequential, Pack = 1)]
   public struct surerecover_schedule_data_t
  {
    [MarshalAs(UnmanagedType.U1)] public surerecover_day_of_week  day_of_week;
    [MarshalAs(UnmanagedType.U1)] public byte hour;
    [MarshalAs(UnmanagedType.U1)] public byte minute;
    [MarshalAs(UnmanagedType.U1)] public byte window_size;
  };


   [StructLayout(LayoutKind.Sequential, Pack = 1)]
   public struct surerecover_schedule_data_payload_t
  {
    [MarshalAs(UnmanagedType.U4)] public UInt32  nonce;
    public surerecover_schedule_data_t schedule;
  };
   [StructLayout(LayoutKind.Sequential, Pack = 1)]
   public struct surerecover_schedule_payload_t
  {
    [MarshalAs(UnmanagedType.ByValArray, ArraySubType = UnmanagedType.I1, SizeConst = 256)]  public byte[] sig;
      public surerecover_schedule_data_payload_t data;
  };


  [StructLayout(LayoutKind.Sequential, Pack = 1)]
  public struct surerecover_state_t
  {
    [MarshalAs(UnmanagedType.ByValArray, SizeConst=2)] public byte[] subsystem_version; // major minor
    [MarshalAs(UnmanagedType.U4)] public UInt32 nonce;
    [MarshalAs(UnmanagedType.U4)] public surerecover_os_flags os_flags;
    [MarshalAs(UnmanagedType.U4)] public surerecover_re_flags re_flags;
    public surerecover_schedule_data_t schedule;
    [MarshalAs(UnmanagedType.U4)] public UInt32 flags;
  };


  public  static  class DfmNativeSureRecover
    {

        [DllImport("dfmbios32.dll", EntryPoint = "sp_get_osr_state", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
    public static extern int get_surerecover_state32([In,Out] ref surerecover_state_t data, [In,Out] ref int extended_result);
        [DllImport("dfmbios64.dll", EntryPoint = "sp_get_osr_state", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
    public static extern int get_surerecover_state64([In,Out] ref surerecover_state_t data, [In,Out] ref int extended_result);

    [DllImport("dfmbios32.dll", EntryPoint = "sp_set_osr_deprovision_opaque", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
    public static extern int set_surerecover_deprovision_opaque32([In] byte[] data, [In] int data_size, [In,Out] ref int extended_result);
        [DllImport("dfmbios64.dll", EntryPoint = "sp_set_osr_deprovision_opaque", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
    public static extern int set_surerecover_deprovision_opaque64([In] byte[] data, [In] int data_size, [In,Out] ref int extended_result);

    [DllImport("dfmbios32.dll", EntryPoint = "sp_set_osr_os_opaque", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
    public static extern int set_surerecover_osr_provisioning32([In] byte[] data, [In] int data_size, [In,Out] ref int extended_result);
        [DllImport("dfmbios64.dll", EntryPoint = "sp_set_osr_os_opaque", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
    public static extern int set_surerecover_osr_provisioning64([In] byte[] data, [In] int data_size, [In,Out] ref int extended_result);

    [DllImport("dfmbios32.dll", EntryPoint = "sp_set_osr_re_opaque", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
    public static extern int set_surerecover_re_provisioning32([In] byte[] data, [In] int data_size, [In,Out] ref int extended_result);
        [DllImport("dfmbios64.dll", EntryPoint = "sp_set_osr_re_opaque", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
    public static extern int set_surerecover_re_provisioning64([In] byte[] data, [In] int data_size, [In,Out] ref int extended_result);

    [DllImport("dfmbios32.dll", EntryPoint = "sp_set_osr_schedule_opaque", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
    public static extern int set_surerecover_schedule32([In] byte[] data, [In] int data_size, [In,Out] ref int extended_result);
        [DllImport("dfmbios64.dll", EntryPoint = "sp_set_osr_schedule_opaque", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
    public static extern int set_surerecover_schedule64([In] byte[] data, [In] int data_size, [In,Out] ref int extended_result);

    [DllImport("dfmbios32.dll", EntryPoint = "sp_get_osr_provisioning_opaque", CharSet = CharSet.Ansi, CallingConvention = CallingConvention.Cdecl)]
    public static extern int get_surerecover_provisioning_opaque32([In] UInt32 nonce, [In] UInt16 version, [In] byte[] ok, [In] UInt32 ok_size, [In] string username, [In] string password, [In] string url,   [In,Out] ref opaque4096_t data, [In,Out] ref int data_len, [In,Out] ref int extended_result);
        [DllImport("dfmbios64.dll", EntryPoint = "sp_get_osr_provisioning_opaque", CharSet = CharSet.Ansi, CallingConvention = CallingConvention.Cdecl)]
    public static extern int get_surerecover_provisioning_opaque64([In] UInt32 nonce, [In] UInt16 version, [In] byte[] ok, [In] UInt32 ok_size, [In] string username, [In] string password, [In] string url,   [In,Out] ref opaque4096_t data, [In,Out] ref int data_len, [In,Out] ref int extended_result);

    [DllImport("dfmbios32.dll", EntryPoint = "sp_set_osr_configuration_opaque", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
    public static extern int set_surerecover_configuration32([In] byte[] data, [In] int data_size, [In,Out] ref int extended_result);
        [DllImport("dfmbios64.dll", EntryPoint = "sp_set_osr_configuration_opaque", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
    public static extern int set_surerecover_configuration64([In] byte[] data, [In] int data_size, [In,Out] ref int extended_result);

    [DllImport("dfmbios32.dll", EntryPoint = "sp_set_osr_trigger_opaque", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
    public static extern int set_surerecover_trigger32([In] byte[] data, [In] int data_size, [In,Out] ref int extended_result);
        [DllImport("dfmbios64.dll", EntryPoint = "sp_set_osr_trigger_opaque", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
    public static extern int set_surerecover_trigger64([In] byte[] data, [In] int data_size, [In,Out] ref int extended_result);

    [DllImport("dfmbios32.dll", EntryPoint = "sp_osr_raise_service_event_opaque", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
    public static extern int raise_surerecover_service_event_opaque32([In] byte[] data, [In] int data_size, [In,Out] ref int extended_result);
        [DllImport("dfmbios64.dll", EntryPoint = "sp_osr_raise_service_event_opaque", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
    public static extern int raise_surerecover_service_event_opaque64([In] byte[] data, [In] int data_size, [In,Out] ref int extended_result);


    }

  public enum sr_activation_state_t : uint
  {
    Deactivated = 0,
    Activated = 1,
    PermanentlyDisabled = 2,
    Suspended = 3,
    ActivatedNoManifest = 4,
    SecurePlatformNotProvisioned = 5,
    ActivationInProgress = 6,
    RecoveryMode = 7
  }

  [Flags]
  public enum sr_config_t : uint
  {
    None = 0,
    HibernateOnHeartbearTimeout = 1
  }

  [Flags]
  public enum sr_capabilities_t : uint
  {
    None = 0,
    ManifestEncryptionSupported = 1
  }


    // HP SureRun
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    public struct surerun_state_t
    {
        [MarshalAs(UnmanagedType.ByValArray, SizeConst=2)] public byte[]  subsystem_version;
        [MarshalAs(UnmanagedType.U4)] public sr_activation_state_t  activation_state;
        [MarshalAs(UnmanagedType.U4)] public UInt32  flags;
        [MarshalAs(UnmanagedType.U4)] public sr_capabilities_t  capabilities;
        [MarshalAs(UnmanagedType.U4)] public UInt32  max_manifest_size;
        [MarshalAs(UnmanagedType.U4)] public UInt32  command_counter;
        [MarshalAs(UnmanagedType.U4)] public sr_config_t  config_flags;
    [MarshalAs(UnmanagedType.BStr)] public string manifest;
    [MarshalAs(UnmanagedType.U4)] public UInt32 manifest_size;
    [MarshalAs(UnmanagedType.U4)] public UInt32 manifest_was_retrieved;
    };

    public struct surerun_manifestinfo_t {
    [MarshalAs(UnmanagedType.ByValArray, ArraySubType = UnmanagedType.I1, SizeConst = 256)]  public byte[] sig;
      public surerun_manifestinfo_payload_t data;
    };

    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    public struct surerun_manifestinfo_payload_t
    {
        [MarshalAs(UnmanagedType.U4)]  public uint counter;
        [MarshalAs(UnmanagedType.U2)]  public ushort total_size;
        [MarshalAs(UnmanagedType.ByValArray, ArraySubType = UnmanagedType.I1, SizeConst = 32)]  public byte[] hash;
    }

    public static class DfmNativeSureRun
    {
        [DllImport("dfmbios32.dll", EntryPoint = "sp_get_sr_state", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
    public static extern int get_surerun_state32([In,Out] ref surerun_state_t data, [In,Out] ref int extended_result, bool include_manifest);
        [DllImport("dfmbios64.dll", EntryPoint = "sp_get_sr_state", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
    public static extern int get_surerun_state64([In,Out] ref surerun_state_t data, [In,Out] ref int extended_result, bool include_manifest);

        [DllImport("dfmbios32.dll", EntryPoint = "sp_set_sr_manifest_opaque", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
    public static extern int set_surererun_manifest32([In] byte[] data, [In] int data_size, [In,Out] ref int extended_result);
        [DllImport("dfmbios64.dll", EntryPoint = "sp_set_sr_manifest_opaque", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
    public static extern int set_surererun_manifest64([In] byte[] data, [In] int data_size, [In,Out] ref int extended_result);
    };

    public static class DfmNativeQRCode
    {
        [DllImport("dfmbios32.dll", EntryPoint = "create_qrcode", CharSet = CharSet.Ansi, CallingConvention = CallingConvention.Cdecl)]
        public static extern int create_qrcode32([In] string data, [In,Out] byte[] qr);
        [DllImport("dfmbios64.dll", EntryPoint = "create_qrcode", CharSet = CharSet.Ansi, CallingConvention = CallingConvention.Cdecl)]
        public static extern int create_qrcode64([In] string data, [In,Out] byte[] qr);

        [DllImport("dfmbios32.dll", EntryPoint = "get_console_font_height", CharSet = CharSet.Ansi, CallingConvention = CallingConvention.Cdecl)]
        public static extern int get_console_font_height32();
        [DllImport("dfmbios64.dll", EntryPoint = "get_console_font_height", CharSet = CharSet.Ansi, CallingConvention = CallingConvention.Cdecl)]
        public static extern int get_console_font_height64();

        [DllImport("dfmbios32.dll", EntryPoint = "get_console_font_width", CharSet = CharSet.Ansi, CallingConvention = CallingConvention.Cdecl)]
        public static extern int get_console_font_width32();
        [DllImport("dfmbios64.dll", EntryPoint = "get_console_font_width", CharSet = CharSet.Ansi, CallingConvention = CallingConvention.Cdecl)]
        public static extern int get_console_font_width64();

        [DllImport("dfmbios32.dll", EntryPoint = "get_screen_scale", CharSet = CharSet.Ansi, CallingConvention = CallingConvention.Cdecl)]
        public static extern float get_screen_scale32();
        [DllImport("dfmbios64.dll", EntryPoint = "get_screen_scale", CharSet = CharSet.Ansi, CallingConvention = CallingConvention.Cdecl)]
        public static extern float get_screen_scale64();
    }

    public struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    public class Win32Window : IWin32Window
    {
        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

        private IntPtr _hWnd;
        private int _data;

        public int Data
        {
            get { return _data; }
            set { _data = value; }
        }

        public Win32Window(IntPtr handle)
        {
            _hWnd = handle;
        }

        public IntPtr Handle
        {
            get { return _hWnd; }
        }
    }

    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    public struct SureAdminSignatureBlockHeader
    {
        public byte Version;
        public UInt16 NameLength;
        public UInt16 ValueLength;
        public byte OneTimeUse;
        public UInt32 Nonce;
        public byte Reserved;
        [MarshalAs(UnmanagedType.ByValArray, ArraySubType = UnmanagedType.I1, SizeConst = 16)]
        public byte[] Target;
    }

    // hp retail

    public enum RetailSmartDockMode : uint
    {
        Fast = 0,
        Pin = 1,
        FastSecure = 2,
        PinSecure = 3,
        Application = 4,
        Unknown = 0xffffffff
    }

    public enum RetailSmartDockState : uint
    {
        Undocked = 0,
        Docked = 1,
        Jammed = 2,
        Unknown = 0xffffffff
    }

    public enum RetailSmartDockHubState  : uint
    {
        None = 0,
        AdvancedConnectivtyBase = 1,
        BasicConnectivityBase = 2,
        Unknown = 0xffffffff
    }

    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    public struct RetailInformation {
        public UInt32 IsSupported;
        public UInt32 Mode;
        public UInt32 DockState;
        public UInt32 HubState;
        public UInt32 Timeout;
        public UInt32 PinSize;
        public UInt32 BaseLockoutTimer;
        public UInt32 RelockTimer;
        public UInt32 DockCounter;
        public UInt32 UndockCounter;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 16)]
        public byte[] Pin;
     }






    public  static  class DfmNativeRetail
    {

            [DllImport("dfmbios32.dll", EntryPoint = "get_retail_dock_configuration", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
            public static extern int get_retail_dock_configuration_32(ref RetailInformation data, [Out] out UInt32 extended_result);
            [DllImport("dfmbios64.dll", EntryPoint = "get_retail_dock_configuration", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
            public static extern int get_retail_dock_configuration_64(ref RetailInformation data, [Out] out UInt32 extended_result);

            [DllImport("dfmbios32.dll", EntryPoint = "set_retail_dock_configuration", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
            public static extern int set_retail_dock_configuration_32(ref RetailInformation data, [Out] out UInt32 extended_result);
            [DllImport("dfmbios64.dll", EntryPoint = "set_retail_dock_configuration", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
            public static extern int set_retail_dock_configuration_64(ref RetailInformation data, [Out] out UInt32 extended_result);


    }

'@ -ReferencedAssemblies 'System.Windows.Forms.dll'






# SIG # Begin signature block
# MIIaygYJKoZIhvcNAQcCoIIauzCCGrcCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB2J1N+vlVI4LRl
# RJTgX1hlvPxW4Vv8KL28b9C8LDLOzaCCCm8wggUwMIIEGKADAgECAhAECRgbX9W7
# ZnVTQ7VvlVAIMA0GCSqGSIb3DQEBCwUAMGUxCzAJBgNVBAYTAlVTMRUwEwYDVQQK
# EwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xJDAiBgNV
# BAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBDQTAeFw0xMzEwMjIxMjAwMDBa
# Fw0yODEwMjIxMjAwMDBaMHIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2Vy
# dCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xMTAvBgNVBAMTKERpZ2lD
# ZXJ0IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNpZ25pbmcgQ0EwggEiMA0GCSqGSIb3
# DQEBAQUAA4IBDwAwggEKAoIBAQD407Mcfw4Rr2d3B9MLMUkZz9D7RZmxOttE9X/l
# qJ3bMtdx6nadBS63j/qSQ8Cl+YnUNxnXtqrwnIal2CWsDnkoOn7p0WfTxvspJ8fT
# eyOU5JEjlpB3gvmhhCNmElQzUHSxKCa7JGnCwlLyFGeKiUXULaGj6YgsIJWuHEqH
# CN8M9eJNYBi+qsSyrnAxZjNxPqxwoqvOf+l8y5Kh5TsxHM/q8grkV7tKtel05iv+
# bMt+dDk2DZDv5LVOpKnqagqrhPOsZ061xPeM0SAlI+sIZD5SlsHyDxL0xY4PwaLo
# LFH3c7y9hbFig3NBggfkOItqcyDQD2RzPJ6fpjOp/RnfJZPRAgMBAAGjggHNMIIB
# yTASBgNVHRMBAf8ECDAGAQH/AgEAMA4GA1UdDwEB/wQEAwIBhjATBgNVHSUEDDAK
# BggrBgEFBQcDAzB5BggrBgEFBQcBAQRtMGswJAYIKwYBBQUHMAGGGGh0dHA6Ly9v
# Y3NwLmRpZ2ljZXJ0LmNvbTBDBggrBgEFBQcwAoY3aHR0cDovL2NhY2VydHMuZGln
# aWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNydDCBgQYDVR0fBHow
# eDA6oDigNoY0aHR0cDovL2NybDQuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJl
# ZElEUm9vdENBLmNybDA6oDigNoY0aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0Rp
# Z2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDBPBgNVHSAESDBGMDgGCmCGSAGG/WwA
# AgQwKjAoBggrBgEFBQcCARYcaHR0cHM6Ly93d3cuZGlnaWNlcnQuY29tL0NQUzAK
# BghghkgBhv1sAzAdBgNVHQ4EFgQUWsS5eyoKo6XqcQPAYPkt9mV1DlgwHwYDVR0j
# BBgwFoAUReuir/SSy4IxLVGLp6chnfNtyA8wDQYJKoZIhvcNAQELBQADggEBAD7s
# DVoks/Mi0RXILHwlKXaoHV0cLToaxO8wYdd+C2D9wz0PxK+L/e8q3yBVN7Dh9tGS
# dQ9RtG6ljlriXiSBThCk7j9xjmMOE0ut119EefM2FAaK95xGTlz/kLEbBw6RFfu6
# r7VRwo0kriTGxycqoSkoGjpxKAI8LpGjwCUR4pwUR6F6aGivm6dcIFzZcbEMj7uo
# +MUSaJ/PQMtARKUT8OZkDCUIQjKyNookAv4vcn4c10lFluhZHen6dGRrsutmQ9qz
# sIzV6Q3d9gEgzpkxYz0IGhizgZtPxpMQBvwHgfqL2vmCSfdibqFT+hKUGIUukpHq
# aGxEMrJmoecYpJpkUe8wggU3MIIEH6ADAgECAhAFUi3UAAgCGeslOwtVg52XMA0G
# CSqGSIb3DQEBCwUAMHIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJ
# bmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xMTAvBgNVBAMTKERpZ2lDZXJ0
# IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNpZ25pbmcgQ0EwHhcNMjEwMzIyMDAwMDAw
# WhcNMjIwMzMwMjM1OTU5WjB1MQswCQYDVQQGEwJVUzETMBEGA1UECBMKQ2FsaWZv
# cm5pYTESMBAGA1UEBxMJUGFsbyBBbHRvMRAwDgYDVQQKEwdIUCBJbmMuMRkwFwYD
# VQQLExBIUCBDeWJlcnNlY3VyaXR5MRAwDgYDVQQDEwdIUCBJbmMuMIIBIjANBgkq
# hkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAtJ+rYUkseHcrB2M/GyomCEyKn9tCyfb+
# pByq/Jyf5kd3BGh+/ULRY7eWmR2cjXHa3qBAEHQQ1R7sX85kZ5sl2ukINGZv5jEM
# 04ERNfPoO9+pDndLWnaGYxxZP9Y+Icla09VqE/jfunhpLYMgb2CuTJkY2tT2isWM
# EMrKtKPKR5v6sfhsW6WOTtZZK+7dQ9aVrDqaIu+wQm/v4hjBYtqgrXT4cNZSPfcj
# 8W/d7lFgF/UvUnZaLU5Z/+lYbPf+449tx+raR6GD1WJBAzHcOpV6tDOI5tQcwHTo
# jJklvqBkPbL+XuS04IUK/Zqgh32YZvDnDohg0AEGilrKNiMes5wuAQIDAQABo4IB
# xDCCAcAwHwYDVR0jBBgwFoAUWsS5eyoKo6XqcQPAYPkt9mV1DlgwHQYDVR0OBBYE
# FD4tECf7wE2l8kA6HTvOgkbo33MvMA4GA1UdDwEB/wQEAwIHgDATBgNVHSUEDDAK
# BggrBgEFBQcDAzB3BgNVHR8EcDBuMDWgM6Axhi9odHRwOi8vY3JsMy5kaWdpY2Vy
# dC5jb20vc2hhMi1hc3N1cmVkLWNzLWcxLmNybDA1oDOgMYYvaHR0cDovL2NybDQu
# ZGlnaWNlcnQuY29tL3NoYTItYXNzdXJlZC1jcy1nMS5jcmwwSwYDVR0gBEQwQjA2
# BglghkgBhv1sAwEwKTAnBggrBgEFBQcCARYbaHR0cDovL3d3dy5kaWdpY2VydC5j
# b20vQ1BTMAgGBmeBDAEEATCBhAYIKwYBBQUHAQEEeDB2MCQGCCsGAQUFBzABhhho
# dHRwOi8vb2NzcC5kaWdpY2VydC5jb20wTgYIKwYBBQUHMAKGQmh0dHA6Ly9jYWNl
# cnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFNIQTJBc3N1cmVkSURDb2RlU2lnbmlu
# Z0NBLmNydDAMBgNVHRMBAf8EAjAAMA0GCSqGSIb3DQEBCwUAA4IBAQBZca1CZfgn
# DucOwEDZk0RXqb8ECXukFiih/rPQ+T5Xvl3bZppGgPnyMyQXXC0fb94p1socJzJZ
# fn7rEQ4tHxL1vpBvCepB3Jq+i3A8nnJFHSjY7aujglIphfGND97U8OUJKt2jwnni
# EgsWZnFHRI9alEvfGEFyFrAuSo+uBz5oyZeOAF0lRqaRht6MtGTma4AEgq6Mk/iP
# LYIIZ5hXmsGYWtIPyM8Yjf//kLNPRn2WeUFROlboU6EH4ZC0rLTMbSK5DV+xL/e8
# cRfWL76gd/qj7OzyJR7EsRPg92RQUC4RJhCrQqFFnmI/K84lPyHRgoctAMb8ie/4
# X6KaoyX0Z93PMYIPsTCCD60CAQEwgYYwcjELMAkGA1UEBhMCVVMxFTATBgNVBAoT
# DERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTExMC8GA1UE
# AxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVkIElEIENvZGUgU2lnbmluZyBDQQIQBVIt
# 1AAIAhnrJTsLVYOdlzANBglghkgBZQMEAgEFAKB8MBAGCisGAQQBgjcCAQwxAjAA
# MBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgor
# BgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCBkxecCmdr+dtZCVcVqIEOEBVEkt8y+
# +hr1QD3vC94G2jANBgkqhkiG9w0BAQEFAASCAQAzvc9lC9HYTqnG3rl13LHW25I6
# A4icztDC1neqcWZ/0hXEW9JGQIBneg3qqHHTcCE9Gumeh/SzBR4zR/U7b1gWLf0c
# npSAe5Yt/1LENl3vMSmwKjWSk6Uu5MnMzQjiDGjawWVh96OqDiBAHZjrszszxQgm
# 4eHhJ2gnMwhBbxh8+BxTBEz6/O4EHc6YSj8headK4IkpsIN7KbwqQ1bwDMgPZz6g
# sNd5lAcXg2fp1v1Tmngjf5tlKkxzjAbBB5HNnUJuqTnATAiZyGReNhh7hX5tjRiN
# n72Nrf6SXDdYmRBXCBKbwZz+qkLt2amgRi2df+OZN7D0lmabe4OraOSswzLsoYIN
# fTCCDXkGCisGAQQBgjcDAwExgg1pMIINZQYJKoZIhvcNAQcCoIINVjCCDVICAQMx
# DzANBglghkgBZQMEAgEFADB3BgsqhkiG9w0BCRABBKBoBGYwZAIBAQYJYIZIAYb9
# bAcBMDEwDQYJYIZIAWUDBAIBBQAEIHlcwNq2wZLl5xVLtbK/a7lRMmTpmnYiuqDS
# abrMm+rWAhB2esFc24n9XPfXFW1pnSYnGA8yMDIxMTEyMjE5MTkwM1qgggo3MIIE
# /jCCA+agAwIBAgIQDUJK4L46iP9gQCHOFADw3TANBgkqhkiG9w0BAQsFADByMQsw
# CQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cu
# ZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFzc3VyZWQgSUQg
# VGltZXN0YW1waW5nIENBMB4XDTIxMDEwMTAwMDAwMFoXDTMxMDEwNjAwMDAwMFow
# SDELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMSAwHgYDVQQD
# ExdEaWdpQ2VydCBUaW1lc3RhbXAgMjAyMTCCASIwDQYJKoZIhvcNAQEBBQADggEP
# ADCCAQoCggEBAMLmYYRnxYr1DQikRcpja1HXOhFCvQp1dU2UtAxQtSYQ/h3Ib5Fr
# DJbnGlxI70Tlv5thzRWRYlq4/2cLnGP9NmqB+in43Stwhd4CGPN4bbx9+cdtCT2+
# anaH6Yq9+IRdHnbJ5MZ2djpT0dHTWjaPxqPhLxs6t2HWc+xObTOKfF1FLUuxUOZB
# OjdWhtyTI433UCXoZObd048vV7WHIOsOjizVI9r0TXhG4wODMSlKXAwxikqMiMX3
# MFr5FK8VX2xDSQn9JiNT9o1j6BqrW7EdMMKbaYK02/xWVLwfoYervnpbCiAvSwnJ
# laeNsvrWY4tOpXIc7p96AXP4Gdb+DUmEvQECAwEAAaOCAbgwggG0MA4GA1UdDwEB
# /wQEAwIHgDAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMEEG
# A1UdIAQ6MDgwNgYJYIZIAYb9bAcBMCkwJwYIKwYBBQUHAgEWG2h0dHA6Ly93d3cu
# ZGlnaWNlcnQuY29tL0NQUzAfBgNVHSMEGDAWgBT0tuEgHf4prtLkYaWyoiWyyBc1
# bjAdBgNVHQ4EFgQUNkSGjqS6sGa+vCgtHUQ23eNqerwwcQYDVR0fBGowaDAyoDCg
# LoYsaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL3NoYTItYXNzdXJlZC10cy5jcmww
# MqAwoC6GLGh0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9zaGEyLWFzc3VyZWQtdHMu
# Y3JsMIGFBggrBgEFBQcBAQR5MHcwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRp
# Z2ljZXJ0LmNvbTBPBggrBgEFBQcwAoZDaHR0cDovL2NhY2VydHMuZGlnaWNlcnQu
# Y29tL0RpZ2lDZXJ0U0hBMkFzc3VyZWRJRFRpbWVzdGFtcGluZ0NBLmNydDANBgkq
# hkiG9w0BAQsFAAOCAQEASBzctemaI7znGucgDo5nRv1CclF0CiNHo6uS0iXEcFm+
# FKDlJ4GlTRQVGQd58NEEw4bZO73+RAJmTe1ppA/2uHDPYuj1UUp4eTZ6J7fz51Kf
# k6ftQ55757TdQSKJ+4eiRgNO/PT+t2R3Y18jUmmDgvoaU+2QzI2hF3MN9PNlOXBL
# 85zWenvaDLw9MtAby/Vh/HUIAHa8gQ74wOFcz8QRcucbZEnYIpp1FUL1LTI4gdr0
# YKK6tFL7XOBhJCVPst/JKahzQ1HavWPWH1ub9y4bTxMd90oNcX6Xt/Q/hOvB46NJ
# ofrOp79Wz7pZdmGJX36ntI5nePk2mOHLKNpbh6aKLzCCBTEwggQZoAMCAQICEAqh
# JdbWMht+QeQF2jaXwhUwDQYJKoZIhvcNAQELBQAwZTELMAkGA1UEBhMCVVMxFTAT
# BgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEk
# MCIGA1UEAxMbRGlnaUNlcnQgQXNzdXJlZCBJRCBSb290IENBMB4XDTE2MDEwNzEy
# MDAwMFoXDTMxMDEwNzEyMDAwMFowcjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERp
# Z2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTExMC8GA1UEAxMo
# RGlnaUNlcnQgU0hBMiBBc3N1cmVkIElEIFRpbWVzdGFtcGluZyBDQTCCASIwDQYJ
# KoZIhvcNAQEBBQADggEPADCCAQoCggEBAL3QMu5LzY9/3am6gpnFOVQoV7YjSsQO
# B0UzURB90Pl9TWh+57ag9I2ziOSXv2MhkJi/E7xX08PhfgjWahQAOPcuHjvuzKb2
# Mln+X2U/4Jvr40ZHBhpVfgsnfsCi9aDg3iI/Dv9+lfvzo7oiPhisEeTwmQNtO4V8
# CdPuXciaC1TjqAlxa+DPIhAPdc9xck4Krd9AOly3UeGheRTGTSQjMF287Dxgaqwv
# B8z98OpH2YhQXv1mblZhJymJhFHmgudGUP2UKiyn5HU+upgPhH+fMRTWrdXyZMt7
# HgXQhBlyF/EXBu89zdZN7wZC/aJTKk+FHcQdPK/P2qwQ9d2srOlW/5MCAwEAAaOC
# Ac4wggHKMB0GA1UdDgQWBBT0tuEgHf4prtLkYaWyoiWyyBc1bjAfBgNVHSMEGDAW
# gBRF66Kv9JLLgjEtUYunpyGd823IDzASBgNVHRMBAf8ECDAGAQH/AgEAMA4GA1Ud
# DwEB/wQEAwIBhjATBgNVHSUEDDAKBggrBgEFBQcDCDB5BggrBgEFBQcBAQRtMGsw
# JAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBDBggrBgEFBQcw
# AoY3aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElE
# Um9vdENBLmNydDCBgQYDVR0fBHoweDA6oDigNoY0aHR0cDovL2NybDQuZGlnaWNl
# cnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDA6oDigNoY0aHR0cDov
# L2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDBQ
# BgNVHSAESTBHMDgGCmCGSAGG/WwAAgQwKjAoBggrBgEFBQcCARYcaHR0cHM6Ly93
# d3cuZGlnaWNlcnQuY29tL0NQUzALBglghkgBhv1sBwEwDQYJKoZIhvcNAQELBQAD
# ggEBAHGVEulRh1Zpze/d2nyqY3qzeM8GN0CE70uEv8rPAwL9xafDDiBCLK938ysf
# DCFaKrcFNB1qrpn4J6JmvwmqYN92pDqTD/iy0dh8GWLoXoIlHsS6HHssIeLWWywU
# NUMEaLLbdQLgcseY1jxk5R9IEBhfiThhTWJGJIdjjJFSLK8pieV4H9YLFKWA1xJH
# cLN11ZOFk362kmf7U2GJqPVrlsD0WGkNfMgBsbkodbeZY4UijGHKeZR+WfyMD+Nv
# tQEmtmyl7odRIeRYYJu6DC0rbaLEfrvEJStHAgh8Sa4TtuF8QkIoxhhWz0E0tmZd
# tnR79VYzIi8iNrJLokqV2PWmjlIxggKGMIICggIBATCBhjByMQswCQYDVQQGEwJV
# UzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQu
# Y29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFzc3VyZWQgSUQgVGltZXN0YW1w
# aW5nIENBAhANQkrgvjqI/2BAIc4UAPDdMA0GCWCGSAFlAwQCAQUAoIHRMBoGCSqG
# SIb3DQEJAzENBgsqhkiG9w0BCRABBDAcBgkqhkiG9w0BCQUxDxcNMjExMTIyMTkx
# OTAzWjArBgsqhkiG9w0BCRACDDEcMBowGDAWBBTh14Ko4ZG+72vKFpG1qrSUpiSb
# 8zAvBgkqhkiG9w0BCQQxIgQgXfulKBotNkrQul12iBlQEIb0wTspzSGi6rgKqUrk
# inMwNwYLKoZIhvcNAQkQAi8xKDAmMCQwIgQgsxCQBrwK2YMHkVcp4EQDQVyD4ykr
# YU8mlkyNNXHs9akwDQYJKoZIhvcNAQEBBQAEggEAmcdPSAYrS51kQr4hvx4c2lGg
# XRP8nydTq/XxzOD0SYKrk7weCuJoPzUTll0zsCO5KoVIgVDPlMA87mr5XN3qMLwK
# h1fqG4Roh/5bhhPkH5Ub2raosanKXJnu/YsLZSpr9+YQ5nE/XhS5OJNcgucDB+Ur
# tV3uYxFN9pGRNsqG+welhG67fIpk2vQ6jrFj12H6dq0V9o5byE+xI8XtH6spw39/
# 6VPg+nnOaL0QeU2VMExn79Cn8D8hySx9zZO8l66ivuqnnIZMgDIV77Jnp4p6tSGa
# pq88ni05J4HRL+a6yKk6q9hEGM+UI2qDU3aCsuu6bHO4hlXh7INr9y16RXKd9g==
# SIG # End signature block
