--
--  File Name:         AlertLogPkg.vhd
--  Design Unit Name:  AlertLogPkg
--  Revision:          STANDARD VERSION
--
--  Maintainer:        Jim Lewis      email:  jim@synthworks.com
--  Contributor(s):
--     Jim Lewis      jim@synthworks.com
--     Rob Gaddi      Highland Technology.    Inspired SetAlertLogPrefix / Suffix
--     Markus Ferringer                       Proposed printing time first with output formatter 
--
--
--  Description:
--        Alert handling and log filtering (verbosity control)
--        Alert handling provides a method to count failures, errors, and warnings
--          To accumlate counts, a data structure is created in a shared variable
--          It is of type AlertLogStructPType which is defined in AlertLogBasePkg
--        Log filtering provides verbosity control for logs (display or do not display)
--        AlertLogPkg provides a simplified interface to the shared variable
--
--
--  Developed for:
--        SynthWorks Design Inc.
--        VHDL Training Classes
--        11898 SW 128th Ave.  Tigard, Or  97223
--        http://www.SynthWorks.com
--
--  Revision History:
--    Date      Version    Description
--    04/2023   2023.04    Added GetTranscriptName.
--    01/2023   2023.01    OSVVM_OUTPUT_DIRECTORY replaced REPORTS_DIRECTORY.
--    11/2022   2022.11    Added GetTestName
--    06/2022   2022.06    Added Output Formatting - WriteTimeLast (vs First)
--                         Minor printing updates to AffirmIfDiff and AlertIfDiff
--                         Added SetTestName in preference of now deprecated SetAlertLogName
--    02/2022   2022.02    SetAlertPrintCount and GetAlertPrintCount
--                         Added NewID with ReportMode, PrintParent
--                         Updated Alert s.t. on StopCount prints WriteAlertSummaryYaml and WriteAlertYaml
--    01/2022   2022.01    For AlertIfEqual and AffirmIfEqual, all arrays of std_ulogic use to_hxstring
--                         Updated return value for PathTail
--    10/2021   2021.10    Moved EndOfTestSummary to ReportPkg
--    09/2021   2021.09    Added EndOfTestSummary and CreateYamlReport - Experimental Release
--    07/2021   2021.07    When printing time value from GetOsvvmDefaultTimeUnits is used.
--    06/2021   2021.06    FindAlertLogID updated to allow an ID name to match the name set by SetAlertLogName (ALERTLOG_BASE_ID)
--    12/2020   2020.12    Added MetaMatch to AffirmIfEqual and AffirmIfNotEqual for std_logic family to use MetaMatch
--                         Added AffirmIfEqual for boolean
--    10/2020   2020.10    Added MetaMatch.
--                         Updated AlertIfEqual and AlertIfNotEqual for std_logic family to use MetaMatch
--    08/2020   2020.08    Alpha Test Release of Specification Tracking - Changes are provisional and subject to change
--                         Added Passed Goals - reported with ReportAlerts and ReportRequirements.
--                         Added WriteAlerts - CSV format of the information in ReportAlerts
--                         Tests fail when requirements are not met and FailOnRequirementErrors is true (default TRUE).
--                             Set using:  SetAlertLogOptions(FailOnRequirementErrors => TRUE)
--                         Turn on requirements printing in summary and details with PrintRequirements (default FALSE,
--                         Turn on requirements printing in summary with PrintIfHaveRequirements (Default TRUE)
--                         Added Requirements Bin, ReadSpecification, GetReqID, SetPassedGoal
--                         Added AffirmIf("Req ID 1", ...) -- will work even if ID not set by GetReqID or ReadSpecification
--                         Added ReportRequirements, WriteRequirements, and ReadRequirements (to merge results of multiple tests)
--                         Added WriteTestSummary, ReadTestSummaries, ReportTestSummaries, and WriteTestSummaries.
--    05/2020   2020.05    Added internal variables AlertCount (W, E, F) and ErrorCount (integer)
--                         that hold the error state.   These can be displayed in wave windows
--                         in simulation to track number of errors.
--                         Calls to std.env.stop now return ErrorCount
--                         Updated calls to check for valid AlertLogIDs
--                         Added affirmation count for each level.
--                           Turn off reporting with SetAlertLogOptions (PrintAffirmations => TRUE) ;
--                         Disabled Alerts now handled in separate bins and reported separately.
--                         Turn off reporting with SetAlertLogOptions (PrintDisabledAlerts => TRUE) ;
--    01/2020   2020.01    Updated Licenses to Apache
--    10/2018   2018.10    Added pragmas to allow alerts, logs, and affirmations in RTL code
--                         Added local variable to mirror top level ErrorCount and display in simulator
--                         Added prefix and suffix
--                         Debug printing with number of errors as prefix
--    04/2018   2018.04    Fix to PathTail.  Prep to change AlertLogIDType to a type.
--    05/2017   2017.05    AffirmIfEqual, AffirmIfDiff,
--                         GetAffirmCount (deprecates GetAffirmCheckCount), IncAffirmCount (deprecates IncAffirmCheckCount),
--                         IsAlertEnabled (alias), IsLogEnabled (alias)
--    02/2016   2016.02    Fixed IsLogEnableType (for PASSED), AffirmIf (to pass AlertLevel)
--                         Created LocalInitialize
--    07/2015   2016.01    Fixed AlertLogID issue with > 32 IDs
--    05/2015   2015.06    Added IncAlertCount, AffirmIf
--    03/2015   2015.03    Added:  AlertIfEqual, AlertIfNotEqual, AlertIfDiff, PathTail,
--                         ReportNonZeroAlerts, ReadLogEnables
--    01/2015   2015.01    Initial revision
--
--  This file is part of OSVVM.
--
--  Copyright (c) 2015 - 2023 by SynthWorks Design Inc.
--
--  Licensed under the Apache License, Version 2.0 (the "License");
--  you may not use this file except in compliance with the License.
--  You may obtain a copy of the License at
--
--      https://www.apache.org/licenses/LICENSE-2.0
--
--  Unless required by applicable law or agreed to in writing, software
--  distributed under the License is distributed on an "AS IS" BASIS,
--  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--  See the License for the specific language governing permissions and
--  limitations under the License.
--


use std.textio.all ;

use work.OsvvmScriptSettingsPkg.all ;
use work.OsvvmGlobalPkg.all ;
use work.TranscriptPkg.all ;
use work.TextUtilPkg.all ;

library IEEE ;
use ieee.std_logic_1164.all ;
use ieee.numeric_std.all ;

package AlertLogPkg is

--  type   AlertLogIDType       is range integer'low to integer'high ; -- next revision
  subtype  AlertLogIDType       is integer ;
  type     AlertLogIDVectorType is array (integer range <>) of AlertLogIDType ;
  type     AlertType            is (FAILURE, ERROR, WARNING) ;  -- NEVER
  subtype  AlertIndexType       is AlertType range FAILURE to WARNING ;
  type     AlertCountType       is array (AlertIndexType) of integer ;
  type     AlertEnableType      is array(AlertIndexType) of boolean ;
  type     LogType              is (ALWAYS, DEBUG, FINAL, INFO, PASSED) ;  -- NEVER  -- See function IsLogEnableType
  subtype  LogIndexType         is LogType range DEBUG to PASSED ;
  type     LogEnableType        is array (LogIndexType) of boolean ;
  type     AlertLogReportModeType  is (DISABLED, ENABLED, NONZERO) ;
  type     AlertLogPrintParentType is (PRINT_NAME, PRINT_NAME_AND_PARENT) ;

  constant  ALERTLOG_BASE_ID               : AlertLogIDType := 0 ;  -- Careful as some code may assume this is 0.
  constant  ALERTLOG_DEFAULT_ID            : AlertLogIDType := ALERTLOG_BASE_ID + 1 ;
  constant  OSVVM_ALERTLOG_ID              : AlertLogIDType := ALERTLOG_BASE_ID + 2 ; -- reporting for packages
  constant  REQUIREMENT_ALERTLOG_ID        : AlertLogIDType := ALERTLOG_BASE_ID + 3 ;
  -- May have its own ID or OSVVM_ALERTLOG_ID as default - most scoreboards allocate their own ID
  constant  OSVVM_SCOREBOARD_ALERTLOG_ID   : AlertLogIDType := OSVVM_ALERTLOG_ID ;
  constant  OSVVM_COV_ALERTLOG_ID          : AlertLogIDType := OSVVM_ALERTLOG_ID ;

  -- Same as ALERTLOG_DEFAULT_ID
  constant  ALERT_DEFAULT_ID               : AlertLogIDType := ALERTLOG_DEFAULT_ID ;
  constant  LOG_DEFAULT_ID                 : AlertLogIDType := ALERTLOG_DEFAULT_ID ;

  constant  ALERTLOG_ID_NOT_FOUND          : AlertLogIDType := -1 ;  -- alternately integer'right
  constant  ALERTLOG_ID_NOT_ASSIGNED       : AlertLogIDType := -1 ;
  constant  MIN_NUM_AL_IDS                 : AlertLogIDType := 32 ; -- Number IDs initially allocated

  ------------------------------------------------------------
  --  Alert always goes to the transcript file
  procedure Alert(
    AlertLogID   : AlertLogIDType ;
    Message      : string ;
    Level        : AlertType := ERROR
  ) ;
  procedure Alert( Message : string ; Level : AlertType := ERROR ) ;

  ------------------------------------------------------------
  procedure IncAlertCount(   -- A silent form of alert
    AlertLogID   : AlertLogIDType ;
    Level        : AlertType := ERROR
  ) ;
  procedure IncAlertCount( Level : AlertType := ERROR ) ;

  ------------------------------------------------------------
  -- Similar to assert, except condition is positive
  procedure AlertIf( AlertLogID : AlertLogIDType ; condition : boolean ; Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIf( condition : boolean ; Message : string ; Level : AlertType := ERROR ) ;
  impure function  AlertIf( AlertLogID : AlertLogIDType ; condition : boolean ; Message : string ; Level : AlertType := ERROR ) return boolean ;
  impure function  AlertIf( condition : boolean ; Message : string ; Level : AlertType := ERROR ) return boolean ;

  ------------------------------------------------------------
  -- Direct replacement for assert
  procedure AlertIfNot( AlertLogID : AlertLogIDType ; condition : boolean ; Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfNot( condition : boolean ; Message : string ; Level : AlertType := ERROR ) ;
  impure function  AlertIfNot( AlertLogID : AlertLogIDType ; condition : boolean ; Message : string ; Level : AlertType := ERROR ) return boolean ;
  impure function  AlertIfNot( condition : boolean ; Message : string ; Level : AlertType := ERROR ) return boolean ;

  ------------------------------------------------------------
  -- overloading for common functionality
  procedure AlertIfEqual( AlertLogID : AlertLogIDType ;  L, R : std_logic ;         Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfEqual( AlertLogID : AlertLogIDType ;  L, R : std_logic_vector ;  Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfEqual( AlertLogID : AlertLogIDType ;  L, R : unsigned ;          Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfEqual( AlertLogID : AlertLogIDType ;  L, R : signed ;            Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfEqual( AlertLogID : AlertLogIDType ;  L, R : integer ;           Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfEqual( AlertLogID : AlertLogIDType ;  L, R : real ;              Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfEqual( AlertLogID : AlertLogIDType ;  L, R : character ;         Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfEqual( AlertLogID : AlertLogIDType ;  L, R : string ;            Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfEqual( AlertLogID : AlertLogIDType ;  L, R : time ;              Message : string ; Level : AlertType := ERROR )  ;

  procedure AlertIfEqual( L, R : std_logic ;        Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfEqual( L, R : std_logic_vector ; Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfEqual( L, R : unsigned ;         Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfEqual( L, R : signed ;           Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfEqual( L, R : integer ;          Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfEqual( L, R : real ;             Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfEqual( L, R : character ;        Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfEqual( L, R : string ;           Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfEqual( L, R : time ;             Message : string ; Level : AlertType := ERROR )  ;

  procedure AlertIfNotEqual( AlertLogID : AlertLogIDType ;  L, R : std_logic ;        Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfNotEqual( AlertLogID : AlertLogIDType ;  L, R : std_logic_vector ; Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfNotEqual( AlertLogID : AlertLogIDType ;  L, R : unsigned ;         Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfNotEqual( AlertLogID : AlertLogIDType ;  L, R : signed ;           Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfNotEqual( AlertLogID : AlertLogIDType ;  L, R : integer ;          Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfNotEqual( AlertLogID : AlertLogIDType ;  L, R : real ;             Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfNotEqual( AlertLogID : AlertLogIDType ;  L, R : character ;        Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfNotEqual( AlertLogID : AlertLogIDType ;  L, R : string ;           Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfNotEqual( AlertLogID : AlertLogIDType ;  L, R : time ;             Message : string ; Level : AlertType := ERROR )  ;

  procedure AlertIfNotEqual( L, R : std_logic ;        Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfNotEqual( L, R : std_logic_vector ; Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfNotEqual( L, R : unsigned ;         Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfNotEqual( L, R : signed ;           Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfNotEqual( L, R : integer ;          Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfNotEqual( L, R : real ;             Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfNotEqual( L, R : character ;        Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfNotEqual( L, R : string ;           Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfNotEqual( L, R : time ;             Message : string ; Level : AlertType := ERROR )  ;

  ------------------------------------------------------------
  -- Simple Diff for file comparisons
  procedure AlertIfDiff (AlertLogID : AlertLogIDType ; Name1, Name2 : string; Message : string := "" ; Level : AlertType := ERROR ) ;
  procedure AlertIfDiff (Name1, Name2 : string; Message : string := "" ; Level : AlertType := ERROR ) ;
  procedure AlertIfDiff (AlertLogID : AlertLogIDType ; file File1, File2 : text; Message : string := "" ; Level : AlertType := ERROR ) ;
  procedure AlertIfDiff (file File1, File2 : text; Message : string := "" ; Level : AlertType := ERROR ) ;

  ------------------------------------------------------------
  ------------------------------------------------------------
  ------------------------------------------------------------
  procedure AffirmIf(
  ------------------------------------------------------------
    AlertLogID       : AlertLogIDType ;
    condition        : boolean ;
    ReceivedMessage  : string ;
    ExpectedMessage  : string ;
    Enable           : boolean  := FALSE   -- override internal enable
  ) ;

  procedure AffirmIf( condition : boolean ; ReceivedMessage, ExpectedMessage : string ; Enable : boolean := FALSE ) ;
  impure function AffirmIf( AlertLogID : AlertLogIDType ; condition : boolean ; ReceivedMessage, ExpectedMessage : string ; Enable : boolean := FALSE ) return boolean ;
  impure function AffirmIf( condition : boolean ; ReceivedMessage, ExpectedMessage : string ; Enable : boolean := FALSE ) return boolean ;

  procedure AffirmIf(
    AlertLogID   : AlertLogIDType ;
    condition    : boolean ;
    Message      : string ;
    Enable       : boolean := FALSE -- override internal enable
  ) ;

  procedure AffirmIf(condition : boolean ; Message : string ;  Enable : boolean := FALSE ) ;
  impure function  AffirmIf( AlertLogID  : AlertLogIDType ; condition : boolean ; Message : string ; Enable : boolean := FALSE ) return boolean ;
  impure function  AffirmIf( condition : boolean ; Message : string ; Enable : boolean := FALSE ) return boolean ;

  ------------------------------------------------------------
  procedure AffirmIfNot( AlertLogID : AlertLogIDType ; condition : boolean ; ReceivedMessage, ExpectedMessage : string ; Enable : boolean := FALSE ) ;
  procedure AffirmIfNot( condition : boolean ; ReceivedMessage, ExpectedMessage : string ; Enable : boolean := FALSE ) ;
  impure function  AffirmIfNot( AlertLogID  : AlertLogIDType ; condition : boolean ; ReceivedMessage, ExpectedMessage : string ; Enable : boolean := FALSE ) return boolean ;
  impure function  AffirmIfNot( condition : boolean ; ReceivedMessage, ExpectedMessage : string ; Enable : boolean := FALSE ) return boolean ;

  ------------------------------------------------------------
  procedure AffirmIfNot( AlertLogID : AlertLogIDType ; condition : boolean ; Message : string ; Enable : boolean := FALSE ) ;
  procedure AffirmIfNot( condition : boolean ; Message : string ; Enable : boolean := FALSE ) ;
  impure function  AffirmIfNot( AlertLogID  : AlertLogIDType ; condition : boolean ; Message : string ; Enable : boolean := FALSE ) return boolean ;
  impure function  AffirmIfNot( condition : boolean ; Message : string ; Enable : boolean := FALSE ) return boolean ;

  ------------------------------------------------------------
  procedure AffirmPassed( AlertLogID : AlertLogIDType ; Message : string ; Enable : boolean := FALSE ) ;
  procedure AffirmPassed( Message : string ; Enable : boolean := FALSE ) ;
  procedure AffirmError( AlertLogID : AlertLogIDType ; Message : string ) ;
  procedure AffirmError( Message : string ) ;

  ------------------------------------------------------------
  procedure AffirmIfEqual( AlertLogID : AlertLogIDType ; Received, Expected : boolean ;  Message : string := "" ; Enable : boolean := FALSE ) ;
  procedure AffirmIfEqual( AlertLogID : AlertLogIDType ; Received, Expected : std_logic ;  Message : string := "" ; Enable : boolean := FALSE ) ;
  procedure AffirmIfEqual( AlertLogID : AlertLogIDType ; Received, Expected : std_logic_vector ; Message : string := "" ; Enable : boolean := FALSE ) ;
  procedure AffirmIfEqual( AlertLogID : AlertLogIDType ; Received, Expected : unsigned ; Message : string := "" ; Enable : boolean := FALSE ) ;
  procedure AffirmIfEqual( AlertLogID : AlertLogIDType ; Received, Expected : signed ; Message : string := "" ; Enable : boolean := FALSE );
  procedure AffirmIfEqual( AlertLogID : AlertLogIDType ; Received, Expected : integer ; Message : string := "" ; Enable : boolean := FALSE ) ;
  procedure AffirmIfEqual( AlertLogID : AlertLogIDType ; Received, Expected : real ; Message : string := "" ; Enable : boolean := FALSE ) ;
  procedure AffirmIfEqual( AlertLogID : AlertLogIDType ; Received, Expected : character ; Message : string := "" ; Enable : boolean := FALSE ) ;
  procedure AffirmIfEqual( AlertLogID : AlertLogIDType ; Received, Expected : string ; Message : string := "" ; Enable : boolean := FALSE ) ;
  procedure AffirmIfEqual( AlertLogID : AlertLogIDType ; Received, Expected : time ; Message : string := "" ; Enable : boolean := FALSE ) ;

  -- Without AlertLogID
  ------------------------------------------------------------
  procedure AffirmIfEqual( Received, Expected : boolean ;  Message : string := "" ; Enable : boolean := FALSE ) ;
  procedure AffirmIfEqual( Received, Expected : std_logic ;  Message : string := "" ; Enable : boolean := FALSE ) ;
  procedure AffirmIfEqual( Received, Expected : std_logic_vector ; Message : string := "" ; Enable : boolean := FALSE ) ;
  procedure AffirmIfEqual( Received, Expected : unsigned ; Message : string := "" ; Enable : boolean := FALSE ) ;
  procedure AffirmIfEqual( Received, Expected : signed ; Message : string := "" ; Enable : boolean := FALSE ) ;
  procedure AffirmIfEqual( Received, Expected : integer ; Message : string := "" ; Enable : boolean := FALSE ) ;
  procedure AffirmIfEqual( Received, Expected : real ; Message : string := "" ; Enable : boolean := FALSE ) ;
  procedure AffirmIfEqual( Received, Expected : character ; Message : string := "" ; Enable : boolean := FALSE ) ;
  procedure AffirmIfEqual( Received, Expected : string ; Message : string := "" ; Enable : boolean := FALSE ) ;
  procedure AffirmIfEqual( Received, Expected : time ; Message : string := "" ; Enable : boolean := FALSE ) ;

  ------------------------------------------------------------
  procedure AffirmIfNotDiff (AlertLogID : AlertLogIDType ; Name1, Name2 : string; Message : string := "" ; Enable : boolean := FALSE ) ;
  procedure AffirmIfNotDiff (Name1, Name2 : string; Message : string := "" ; Enable : boolean := FALSE ) ;
  procedure AffirmIfNotDiff (AlertLogID : AlertLogIDType ; file File1, File2 : text; Message : string := "" ; Enable : boolean := FALSE ) ;
  procedure AffirmIfNotDiff (file File1, File2 : text; Message : string := "" ; Enable : boolean := FALSE ) ;
-- Deprecated as they are misnamed - should be AffirmIfNotDiff
  procedure AffirmIfDiff (AlertLogID : AlertLogIDType ; Name1, Name2 : string; Message : string := "" ; Enable : boolean := FALSE ) ;
  procedure AffirmIfDiff (Name1, Name2 : string; Message : string := "" ; Enable : boolean := FALSE ) ;
  procedure AffirmIfDiff (AlertLogID : AlertLogIDType ; file File1, File2 : text; Message : string := "" ; Enable : boolean := FALSE ) ;
  procedure AffirmIfDiff (file File1, File2 : text; Message : string := "" ; Enable : boolean := FALSE ) ;

  ------------------------------------------------------------
  -- Support for Specification / Requirements Tracking
  procedure AffirmIf( RequirementsIDName : string ; condition : boolean ; ReceivedMessage, ExpectedMessage : string ; Enable : boolean := FALSE ) ;
  procedure AffirmIf( RequirementsIDName : string ; condition : boolean ; Message : string ; Enable : boolean := FALSE ) ;

  ------------------------------------------------------------
  procedure SetAlertLogJustify (Enable : boolean := TRUE) ;
  procedure ReportAlerts ( Name : String ; AlertCount : AlertCountType ) ;
  procedure ReportRequirements ;
  procedure ReportAlerts (
    Name           : string          := OSVVM_STRING_INIT_PARM_DETECT ;
    AlertLogID     : AlertLogIDType  := ALERTLOG_BASE_ID ;
    ExternalErrors : AlertCountType  := (others => 0) ;
    ReportAll      : Boolean         := FALSE
  ) ;

  procedure ReportNonZeroAlerts (
    Name           : string          := OSVVM_STRING_INIT_PARM_DETECT ;
    AlertLogID     : AlertLogIDType  := ALERTLOG_BASE_ID ;
    ExternalErrors : AlertCountType  := (others => 0)
  ) ;

  procedure WriteAlertYaml (
    FileName       : string ;
    ExternalErrors : AlertCountType := (0,0,0) ;
    Prefix         : string := "" ;
    PrintSettings  : boolean := TRUE ;
    PrintChildren  : boolean := TRUE ;
    OpenKind       : File_Open_Kind := WRITE_MODE
  ) ;
  procedure WriteAlertSummaryYaml (FileName : string := "" ; ExternalErrors : AlertCountType := (0,0,0)) ;
  procedure CreateYamlReport (ExternalErrors : AlertCountType := (0,0,0)) ;  -- Deprecated.  Use WriteAlertSummaryYaml.

-- These are in ReportPkg due to circular dependencies
--  impure function EndOfTestReports (
--    ReportAll      : boolean        := FALSE ;
--    ExternalErrors : AlertCountType := (0,0,0)
--  ) return integer ;
--
--  procedure EndOfTestReports (
--    ReportAll      : boolean        := FALSE ;
--    ExternalErrors : AlertCountType := (0,0,0) ;
--    Stop           : boolean        := FALSE
--  ) ;
--
--  alias EndOfTestSummary is EndOfTestReports[boolean, AlertCountType return integer] ;
--  alias EndOfTestSummary is EndOfTestReports[boolean, AlertCountType, boolean] ;

  procedure WriteTestSummary   (
    FileName       : string ;
    OpenKind       : File_Open_Kind := APPEND_MODE ;
    Prefix         : string := "" ;
    Suffix         : string := "" ;
    ExternalErrors : AlertCountType := (0,0,0) ;
    WriteFieldName : boolean := FALSE
  ) ;
  procedure WriteTestSummaries ( FileName : string ; OpenKind : File_Open_Kind := WRITE_MODE ) ;
  procedure ReportTestSummaries ;
  procedure WriteAlerts (
    FileName    : string ;
    AlertLogID  : AlertLogIDType := ALERTLOG_BASE_ID ;
    OpenKind    : File_Open_Kind := WRITE_MODE
  ) ;
  procedure WriteRequirements (
    FileName        : string ;
    AlertLogID      : AlertLogIDType := REQUIREMENT_ALERTLOG_ID ;
    OpenKind        : File_Open_Kind := WRITE_MODE
  ) ;
  procedure ReadSpecification (FileName : string ; PassedGoal : integer := -1) ;
  procedure ReadRequirements (
    FileName        : string ;
    ThresholdPassed : boolean := FALSE
  ) ;
  procedure ReadTestSummaries (FileName : string) ;
  procedure ClearAlerts ;
  procedure ClearAlertStopCounts ;
  procedure ClearAlertCounts ;
  function "ABS" (L : AlertCountType) return AlertCountType ;
  function "+" (L, R : AlertCountType) return AlertCountType ;
  function "-" (L, R : AlertCountType) return AlertCountType ;
  function "-" (R : AlertCountType) return AlertCountType ;
  impure function SumAlertCount(AlertCount: AlertCountType) return integer ;
  impure function GetAlertCount(AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID) return AlertCountType ;
  impure function GetAlertCount(AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID) return integer ;
  impure function GetEnabledAlertCount(AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID) return AlertCountType ;
  impure function GetEnabledAlertCount(AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID) return integer ;
  impure function GetDisabledAlertCount return AlertCountType ;
  impure function GetDisabledAlertCount return integer ;
  impure function GetDisabledAlertCount(AlertLogID: AlertLogIDType) return AlertCountType ;
  impure function GetDisabledAlertCount(AlertLogID: AlertLogIDType) return integer ;

  ------------------------------------------------------------
  --  log filtering for verbosity control, optionally has a separate file parameter
  procedure Log(
    AlertLogID   : AlertLogIDType ;
    Message      : string ;
    Level        : LogType := ALWAYS ;
    Enable       : boolean := FALSE    -- override internal enable
  ) ;
  procedure Log( Message : string ; Level : LogType := ALWAYS ; Enable : boolean := FALSE) ;

  ------------------------------------------------------------
  -- Alert Enables
  procedure SetAlertEnable(Level : AlertType ;  Enable : boolean) ;
  procedure SetAlertEnable(AlertLogID : AlertLogIDType ;  Level : AlertType ;  Enable : boolean ; DescendHierarchy : boolean := TRUE) ;
  impure function GetAlertEnable(AlertLogID : AlertLogIDType ;  Level : AlertType) return boolean ;
  impure function GetAlertEnable(Level : AlertType) return boolean ;
  alias IsAlertEnabled is GetAlertEnable[AlertLogIDType, AlertType return boolean] ;
  alias IsAlertEnabled is GetAlertEnable[AlertType return boolean] ;

  -- Log Enables
  procedure SetLogEnable(Level : LogType ;  Enable : boolean) ;
  procedure SetLogEnable(AlertLogID : AlertLogIDType ;  Level : LogType ;  Enable : boolean ; DescendHierarchy : boolean := TRUE) ;
  impure function GetLogEnable(AlertLogID : AlertLogIDType ;  Level : LogType) return boolean ;
  impure function GetLogEnable(Level : LogType) return boolean ;
  alias IsLogEnabled is GetLogEnable [AlertLogIDType, LogType return boolean] ;  -- same as GetLogEnable
  alias IsLogEnabled is GetLogEnable [LogType return boolean] ;  -- same as GetLogEnable

  procedure ReportLogEnables ;

  procedure SetTestName(Name : string ) ;
  alias SetAlertLogName is SetTestName [string] ;

  -- synthesis translate_off
  impure function GetTestName return string ;
  impure function GetTranscriptName return string ;
  impure function GetAlertLogName(AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID) return string ;
  -- synthesis translate_on
  procedure DeallocateAlertLogStruct ;
  procedure InitializeAlertLogStruct ;
  impure function FindAlertLogID(Name : string ) return AlertLogIDType ;
  impure function FindAlertLogID(Name : string ; ParentID : AlertLogIDType) return AlertLogIDType ;
  impure function NewID(
    Name            : string ;
    ParentID        : AlertLogIDType          := ALERTLOG_ID_NOT_ASSIGNED ;
    ReportMode      : AlertLogReportModeType  := ENABLED ;
    PrintParent     : AlertLogPrintParentType := PRINT_NAME_AND_PARENT ;
    CreateHierarchy : boolean                 := TRUE
  ) return AlertLogIDType ;
  impure function GetReqID(Name : string ; PassedGoal : integer := -1 ; ParentID : AlertLogIDType := ALERTLOG_ID_NOT_ASSIGNED ; CreateHierarchy : Boolean := TRUE) return AlertLogIDType ;
  procedure SetPassedGoal(AlertLogID : AlertLogIDType ; PassedGoal : integer ) ;
  impure function GetAlertLogParentID(AlertLogID : AlertLogIDType) return AlertLogIDType ;
  procedure SetAlertLogPrefix(AlertLogID : AlertLogIDType; Name : string ) ;
  procedure UnSetAlertLogPrefix(AlertLogID : AlertLogIDType) ;
  -- synthesis translate_off
  impure function GetAlertLogPrefix(AlertLogID : AlertLogIDType) return string ;
  -- synthesis translate_on
  procedure SetAlertLogSuffix(AlertLogID : AlertLogIDType; Name : string ) ;
  procedure UnSetAlertLogSuffix(AlertLogID : AlertLogIDType) ;
  -- synthesis translate_off
  impure function GetAlertLogSuffix(AlertLogID : AlertLogIDType) return string ;
  -- synthesis translate_on

  ------------------------------------------------------------
  -- Accessor Methods
  procedure SetGlobalAlertEnable (A : boolean := TRUE) ;
  impure function SetGlobalAlertEnable (A : boolean := TRUE) return boolean ;
  impure function GetGlobalAlertEnable return boolean ;
  procedure IncAffirmCount(AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID) ;
  impure function GetAffirmCount return natural ;
  procedure IncAffirmPassedCount(AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID) ;
  impure function GetAffirmPassedCount return natural ;

  procedure SetAlertStopCount(AlertLogID : AlertLogIDType ;  Level : AlertType ;  Count : integer) ;
  procedure SetAlertStopCount(Level : AlertType ;  Count : integer) ;
  impure function GetAlertStopCount(AlertLogID : AlertLogIDType ;  Level : AlertType) return integer ;
  impure function GetAlertStopCount(Level : AlertType) return integer ;

  procedure SetAlertPrintCount(AlertLogID : AlertLogIDType ;  Level : AlertType ;  Count : integer) ;
  procedure SetAlertPrintCount(                               Level : AlertType ;  Count : integer) ;
  impure function GetAlertPrintCount(AlertLogID : AlertLogIDType ;  Level : AlertType) return integer ;
  impure function GetAlertPrintCount(                               Level : AlertType) return integer ;
  procedure SetAlertPrintCount(AlertLogID : AlertLogIDType ;  Count : AlertCountType) ;
  procedure SetAlertPrintCount(                               Count : AlertCountType) ;
  impure function GetAlertPrintCount(AlertLogID : AlertLogIDType) return AlertCountType ;
  impure function GetAlertPrintCount                              return AlertCountType ;

  procedure SetAlertLogPrintParent(AlertLogID : AlertLogIDType ;  PrintParent : AlertLogPrintParentType) ;
  procedure SetAlertLogPrintParent(                               PrintParent : AlertLogPrintParentType) ;
  impure function GetAlertLogPrintParent(AlertLogID : AlertLogIDType) return AlertLogPrintParentType ;
  impure function GetAlertLogPrintParent                              return AlertLogPrintParentType ;

  procedure SetAlertLogReportMode(AlertLogID : AlertLogIDType ;  ReportMode : AlertLogReportModeType) ;
  procedure SetAlertLogReportMode(                               ReportMode : AlertLogReportModeType) ;
  impure function GetAlertLogReportMode(AlertLogID : AlertLogIDType) return AlertLogReportModeType ;
  impure function GetAlertLogReportMode                              return AlertLogReportModeType ;

  ------------------------------------------------------------
  procedure SetAlertLogOptions (
    FailOnWarning            : OsvvmOptionsType := OPT_INIT_PARM_DETECT ;
    FailOnDisabledErrors     : OsvvmOptionsType := OPT_INIT_PARM_DETECT ;
    FailOnRequirementErrors  : OsvvmOptionsType := OPT_INIT_PARM_DETECT ;
    ReportHierarchy          : OsvvmOptionsType := OPT_INIT_PARM_DETECT ;
    WriteAlertErrorCount     : OsvvmOptionsType := OPT_INIT_PARM_DETECT ;
    WriteAlertLevel          : OsvvmOptionsType := OPT_INIT_PARM_DETECT ;
    WriteAlertName           : OsvvmOptionsType := OPT_INIT_PARM_DETECT ;
    WriteAlertTime           : OsvvmOptionsType := OPT_INIT_PARM_DETECT ;
    WriteLogErrorCount       : OsvvmOptionsType := OPT_INIT_PARM_DETECT ;
    WriteLogLevel            : OsvvmOptionsType := OPT_INIT_PARM_DETECT ;
    WriteLogName             : OsvvmOptionsType := OPT_INIT_PARM_DETECT ;
    WriteLogTime             : OsvvmOptionsType := OPT_INIT_PARM_DETECT ;
    PrintPassed              : OsvvmOptionsType := OPT_INIT_PARM_DETECT ;
    PrintAffirmations        : OsvvmOptionsType := OPT_INIT_PARM_DETECT ;
    PrintDisabledAlerts      : OsvvmOptionsType := OPT_INIT_PARM_DETECT ;
    PrintRequirements        : OsvvmOptionsType := OPT_INIT_PARM_DETECT ;
    PrintIfHaveRequirements  : OsvvmOptionsType := OPT_INIT_PARM_DETECT ;
    DefaultPassedGoal        : integer             := integer'left ;
    AlertPrefix              : string := OSVVM_STRING_INIT_PARM_DETECT ;
    LogPrefix                : string := OSVVM_STRING_INIT_PARM_DETECT ;
    ReportPrefix             : string := OSVVM_STRING_INIT_PARM_DETECT ;
    DoneName                 : string := OSVVM_STRING_INIT_PARM_DETECT ;
    PassName                 : string := OSVVM_STRING_INIT_PARM_DETECT ;
    FailName                 : string := OSVVM_STRING_INIT_PARM_DETECT ;
    IdSeparator              : string := OSVVM_STRING_INIT_PARM_DETECT ;
    WriteTimeLast            : OsvvmOptionsType := OPT_INIT_PARM_DETECT ;
    TimeJustifyAmount        : integer             := integer'left 
  ) ;

  procedure ReportAlertLogOptions ;


  -- synthesis translate_off

  impure function GetAlertLogFailOnWarning            return OsvvmOptionsType ;
  impure function GetAlertLogFailOnDisabledErrors     return OsvvmOptionsType ;
  impure function GetAlertLogFailOnRequirementErrors  return OsvvmOptionsType ;
  impure function GetAlertLogReportHierarchy          return OsvvmOptionsType ;
  impure function GetAlertLogFoundReportHier          return boolean ;
  impure function GetAlertLogFoundAlertHier           return boolean ;
  impure function GetAlertLogWriteAlertErrorCount     return OsvvmOptionsType ;
  impure function GetAlertLogWriteAlertLevel          return OsvvmOptionsType ;
  impure function GetAlertLogWriteAlertName           return OsvvmOptionsType ;
  impure function GetAlertLogWriteAlertTime           return OsvvmOptionsType ;
  impure function GetAlertLogWriteLogErrorCount       return OsvvmOptionsType ;
  impure function GetAlertLogWriteLogLevel            return OsvvmOptionsType ;
  impure function GetAlertLogWriteLogName             return OsvvmOptionsType ;
  impure function GetAlertLogWriteLogTime             return OsvvmOptionsType ;
  impure function GetAlertLogPrintPassed              return OsvvmOptionsType ;
  impure function GetAlertLogPrintAffirmations        return OsvvmOptionsType ;
  impure function GetAlertLogPrintDisabledAlerts      return OsvvmOptionsType ;
  impure function GetAlertLogPrintRequirements        return OsvvmOptionsType ;
  impure function GetAlertLogPrintIfHaveRequirements  return OsvvmOptionsType ;
  impure function GetAlertLogDefaultPassedGoal        return integer ;

  impure function GetAlertLogAlertPrefix              return string ;
  impure function GetAlertLogLogPrefix                return string ;

  impure function GetAlertLogReportPrefix             return string ;
  impure function GetAlertLogDoneName                 return string ;
  impure function GetAlertLogPassName                 return string ;
  impure function GetAlertLogFailName                 return string ;

  impure function GetAlertLogWriteTimeLast            return OsvvmOptionsType ;

  -- File Reading Utilities
  function IsLogEnableType (Name : String) return boolean ;
  procedure ReadLogEnables (file AlertLogInitFile : text) ;
  procedure ReadLogEnables (FileName : string) ;

  -- String Helper Functions -- This should be in a more general string package
  function PathTail (A : string) return string ;

  ------------------------------------------------------------
  -- MetaMatch
  --   Similar to STD_MATCH, except
  --   it returns TRUE for U=U, X=X, Z=Z, and W=W
  --   All other values are consistent with STD_MATCH
  --   MetaMatch, BooleanTableType, and MetaMatchTable are derivatives
  --   of STD_MATCH from IEEE.Numeric_Std copyright by IEEE.
  --   Numeric_Std is also released under the Apache License, Version 2.0.
  --   Coding Styles were updated to match OSVVM
  ------------------------------------------------------------
  function MetaMatch (l, r : std_ulogic) return boolean ;
  function MetaMatch (L, R : std_ulogic_vector) return boolean ;
  function MetaMatch (L, R : unresolved_unsigned) return boolean ;
  function MetaMatch (L, R : unresolved_signed) return boolean ;

  ------------------------------------------------------------
  -- Helper function for NewID in data structures
  function ResolvePrintParent (
  ------------------------------------------------------------
    UniqueParent : boolean ;
    PrintParent  : AlertLogPrintParentType
  ) return AlertLogPrintParentType ;


  -- synthesis translate_on

  --  ------------------------------------------------------------
  -- Deprecated
  --
  -- See NewID - consistency and parameter update.  DoNotReport replaced by ReportMode
  impure function GetAlertLogID(Name : string; ParentID : AlertLogIDType := ALERTLOG_ID_NOT_ASSIGNED; CreateHierarchy : Boolean := TRUE; DoNotReport : Boolean := FALSE) return AlertLogIDType ;

  -- deprecated
  procedure AlertIf( condition : boolean ; AlertLogID : AlertLogIDType ; Message : string ; Level : AlertType := ERROR )  ;
  impure function  AlertIf( condition : boolean ; AlertLogID : AlertLogIDType ; Message : string ; Level : AlertType := ERROR ) return boolean ;

  -- deprecated
  procedure AlertIfNot( condition : boolean ; AlertLogID : AlertLogIDType ; Message : string ; Level : AlertType := ERROR )  ;
  impure function  AlertIfNot( condition : boolean ; AlertLogID : AlertLogIDType ; Message : string ; Level : AlertType := ERROR ) return boolean ;

  -- deprecated
  procedure AffirmIf(
    AlertLogID   : AlertLogIDType ;
    condition    : boolean ;
    Message      : string ;
    LogLevel     : LogType  ;  -- := PASSED
    AlertLevel   : AlertType := ERROR
  )  ;
  procedure AffirmIf( AlertLogID : AlertLogIDType ; condition : boolean ; Message : string ; AlertLevel : AlertType ) ;
  procedure AffirmIf(condition : boolean ; Message : string ;  LogLevel : LogType  ; AlertLevel : AlertType := ERROR) ;
  procedure AffirmIf(condition : boolean ; Message : string ;  AlertLevel : AlertType ) ;

  alias IncAffirmCheckCount is IncAffirmCount [AlertLogIDType] ;
  alias GetAffirmCheckCount is GetAffirmCount [return natural] ;
  alias IsLoggingEnabled is GetLogEnable [AlertLogIDType, LogType return boolean] ;  -- same as IsLogEnabled
  alias IsLoggingEnabled is GetLogEnable [LogType return boolean] ;  -- same as IsLogEnabled


end AlertLogPkg ;

--- ///////////////////////////////////////////////////////////////////////////
--- ///////////////////////////////////////////////////////////////////////////
--- ///////////////////////////////////////////////////////////////////////////

use work.NamePkg.all ;

package body AlertLogPkg is

-- synthesis translate_off

  -- instead of justify(to_upper(to_string())), just look up the upper case, left justified values
  type     AlertNameType is array(AlertType) of string(1 to 7) ;
  constant ALERT_NAME : AlertNameType := (WARNING => "WARNING", ERROR => "ERROR  ", FAILURE => "FAILURE") ;  -- , NEVER => "NEVER  "
  type     LogNameType is array(LogType) of string(1 to 7) ;
  constant LOG_NAME : LogNameType := (DEBUG => "DEBUG  ", FINAL => "FINAL  ", INFO => "INFO   ", ALWAYS => "ALWAYS ", PASSED => "PASSED ") ; -- , NEVER => "NEVER  "

  ------------------------------------------------------------
  -- Package Local
  function LeftJustify(A : String;  Amount : integer) return string is
  ------------------------------------------------------------
    constant Spaces : string(1 to  maximum(1, Amount)) := (others => ' ') ;
  begin
    if A'length >= Amount then
      return A ;
    else
      return A & Spaces(1 to Amount - A'length) ;
    end if ;
  end function LeftJustify ;


  type AlertLogStructPType is protected

    ------------------------------------------------------------
    procedure alert (
    ------------------------------------------------------------
      AlertLogID   : AlertLogIDType ;
      message      : string ;
      level        : AlertType := ERROR
    ) ;

    ------------------------------------------------------------
    procedure IncAlertCount ( AlertLogID : AlertLogIDType ; level : AlertType := ERROR ) ;
    procedure SetJustify (
      Enable      : boolean := TRUE ;
      AlertLogID  : AlertLogIDType := ALERTLOG_BASE_ID
    ) ;
    procedure ReportAlerts ( Name : string ; AlertCount : AlertCountType ) ;
    procedure ReportRequirements ;
    procedure ReportAlerts (
      Name           : string := OSVVM_STRING_INIT_PARM_DETECT ;
      AlertLogID     : AlertLogIDType := ALERTLOG_BASE_ID ;
      ExternalErrors : AlertCountType := (0,0,0) ;
      ReportAll      : boolean := FALSE ;
      ReportWhenZero : boolean := TRUE
    ) ;
    procedure WriteAlertYaml (
      FileName       : string ;
      ExternalErrors : AlertCountType := (0,0,0) ;
      Prefix         : string := "" ;
      PrintSettings  : boolean := TRUE ;
      PrintChildren  : boolean := TRUE ;
      OpenKind       : File_Open_Kind := WRITE_MODE
    ) ;
    procedure WriteTestSummary (
      FileName       : string ;
      OpenKind       : File_Open_Kind ;
      Prefix         : string ;
      Suffix         : string ;
      ExternalErrors : AlertCountType ;
      WriteFieldName : boolean
    ) ;
    procedure WriteTestSummaries ( FileName : string ; OpenKind : File_Open_Kind ) ;
    procedure ReportTestSummaries ;
    procedure WriteAlerts (
      FileName    : string ;
      AlertLogID  : AlertLogIDType ;
      OpenKind    : File_Open_Kind
    ) ;
    procedure WriteRequirements (
      FileName    : string ;
      AlertLogID  : AlertLogIDType ;
      OpenKind    : File_Open_Kind
    ) ;
    procedure ReadSpecification (FileName : string ; PassedGoal : integer ) ;
    procedure ReadRequirements (
      FileName        : string ;
      ThresholdPassed : boolean ;
      TestSummary     : boolean
    ) ;
    procedure ClearAlerts ;
    procedure ClearAlertStopCounts ;
    impure function GetAlertCount(AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID) return AlertCountType ;
    impure function GetEnabledAlertCount(AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID) return AlertCountType ;
    impure function GetDisabledAlertCount return AlertCountType ;
    impure function GetDisabledAlertCount(AlertLogID: AlertLogIDType) return AlertCountType ;

    ------------------------------------------------------------
    procedure log (
    ------------------------------------------------------------
      AlertLogID   : AlertLogIDType ;
      Message      : string ;
      Level        : LogType := ALWAYS ;
      Enable       : boolean := FALSE    -- override internal enable
    ) ;

    ------------------------------------------------------------
    -- FILE IO Controls
--    procedure SetTranscriptEnable (A : boolean := TRUE) ;
--    impure function IsTranscriptEnabled return boolean ;
--    procedure MirrorTranscript (A : boolean := TRUE) ;
--    impure function IsTranscriptMirrored return boolean ;

    ------------------------------------------------------------
    ------------------------------------------------------------
    -- AlertLog Structure Creation and Interaction Methods

    ------------------------------------------------------------
    procedure SetTestName(Name : string ) ;
    procedure SetNumAlertLogIDs (NewNumAlertLogIDs : AlertLogIDType) ;
    impure function FindAlertLogID(Name : string ) return AlertLogIDType ;
    impure function FindAlertLogID(Name : string ; ParentID : AlertLogIDType) return AlertLogIDType ;
    impure function NewID(
      Name            : string ;
      ParentID        : AlertLogIDType ;
      ReportMode      : AlertLogReportModeType ;
      PrintParent     : AlertLogPrintParentType ;
      CreateHierarchy : boolean
    ) return AlertLogIDType ;
    -- impure function GetAlertLogID(Name : string; ParentID : AlertLogIDType; CreateHierarchy : Boolean; DoNotReport : Boolean) return AlertLogIDType ;
    impure function GetReqID(Name : string ; PassedGoal : integer ; ParentID : AlertLogIDType ; CreateHierarchy : Boolean) return AlertLogIDType ;
    procedure SetPassedGoal(AlertLogID : AlertLogIDType ; PassedGoal : integer ) ;
    impure function GetAlertLogParentID(AlertLogID : AlertLogIDType) return AlertLogIDType ;
    procedure Initialize(NewNumAlertLogIDs : AlertLogIDType := MIN_NUM_AL_IDS) ;
    procedure DeallocateAlertLogStruct ;
    procedure SetAlertLogPrefix(AlertLogID : AlertLogIDType; Name : string ) ;
    procedure UnSetAlertLogPrefix(AlertLogID : AlertLogIDType) ;
    impure function GetAlertLogPrefix(AlertLogID : AlertLogIDType) return string ;
    procedure SetAlertLogSuffix(AlertLogID : AlertLogIDType; Name : string ) ;
    procedure UnSetAlertLogSuffix(AlertLogID : AlertLogIDType) ;
    impure function GetAlertLogSuffix(AlertLogID : AlertLogIDType) return string ;

    ------------------------------------------------------------
    ------------------------------------------------------------
    -- Accessor Methods
    ------------------------------------------------------------
    procedure SetGlobalAlertEnable (A : boolean := TRUE) ;
    impure function GetAlertLogName(AlertLogID : AlertLogIDType) return string ;
    impure function GetGlobalAlertEnable return boolean ;
    procedure IncAffirmCount(AlertLogID : AlertLogIDType) ;
    impure function GetAffirmCount return natural ;
    procedure IncAffirmPassedCount(AlertLogID : AlertLogIDType) ;
    impure function GetAffirmPassedCount return natural ;

    procedure SetAlertStopCount(AlertLogID : AlertLogIDType ;  Level : AlertType ;  Count : integer) ;
    impure function GetAlertStopCount(AlertLogID : AlertLogIDType ;  Level : AlertType) return integer ;

    procedure SetAlertPrintCount(AlertLogID : AlertLogIDType ;  Level : AlertType ;  Count : integer) ;
    impure function GetAlertPrintCount(AlertLogID : AlertLogIDType ;  Level : AlertType) return integer ;

    procedure SetAlertPrintCount(AlertLogID : AlertLogIDType ;  Count : AlertCountType) ;
    impure function GetAlertPrintCount(AlertLogID : AlertLogIDType) return AlertCountType ;

    procedure SetAlertLogPrintParent(AlertLogID : AlertLogIDType ;  PrintParent : AlertLogPrintParentType) ;
    impure function GetAlertLogPrintParent(AlertLogID : AlertLogIDType) return AlertLogPrintParentType ;

    procedure SetAlertLogReportMode(AlertLogID : AlertLogIDType ;  ReportMode : AlertLogReportModeType) ;
    impure function GetAlertLogReportMode(AlertLogID : AlertLogIDType) return AlertLogReportModeType ;

    procedure SetAlertEnable(Level : AlertType ;  Enable : boolean) ;
    procedure SetAlertEnable(AlertLogID : AlertLogIDType ;  Level : AlertType ;  Enable : boolean ; DescendHierarchy : boolean := TRUE) ;
    impure function GetAlertEnable(AlertLogID : AlertLogIDType ;  Level : AlertType) return boolean ;

    procedure SetLogEnable(Level : LogType ;  Enable : boolean) ;
    procedure SetLogEnable(AlertLogID : AlertLogIDType ;  Level : LogType ;  Enable : boolean ; DescendHierarchy : boolean := TRUE) ;
    impure function GetLogEnable(AlertLogID : AlertLogIDType ;  Level : LogType) return boolean ;

    procedure ReportLogEnables ;

    ------------------------------------------------------------
    -- Reporting Accessor
    procedure SetAlertLogOptions (
      FailOnWarning            : OsvvmOptionsType ;
      FailOnDisabledErrors     : OsvvmOptionsType ;
      FailOnRequirementErrors  : OsvvmOptionsType ;
      ReportHierarchy          : OsvvmOptionsType ;
      WriteAlertErrorCount     : OsvvmOptionsType ;
      WriteAlertLevel          : OsvvmOptionsType ;
      WriteAlertName           : OsvvmOptionsType ;
      WriteAlertTime           : OsvvmOptionsType ;
      WriteLogErrorCount       : OsvvmOptionsType ;
      WriteLogLevel            : OsvvmOptionsType ;
      WriteLogName             : OsvvmOptionsType ;
      WriteLogTime             : OsvvmOptionsType ;
      PrintPassed              : OsvvmOptionsType ;
      PrintAffirmations        : OsvvmOptionsType ;
      PrintDisabledAlerts      : OsvvmOptionsType ;
      PrintRequirements        : OsvvmOptionsType ;
      PrintIfHaveRequirements  : OsvvmOptionsType ;
      DefaultPassedGoal        : integer ;
      AlertPrefix              : string ;
      LogPrefix                : string ;
      ReportPrefix             : string ;
      DoneName                 : string ;
      PassName                 : string ;
      FailName                 : string ;
      IdSeparator              : string ;
      WriteTimeLast            : OsvvmOptionsType ;
      TimeJustifyAmount        : integer 
    ) ;
    procedure ReportAlertLogOptions ;

    impure function GetAlertLogFailOnWarning        return OsvvmOptionsType ;
    impure function GetAlertLogFailOnDisabledErrors return OsvvmOptionsType ;
    impure function GetAlertLogFailOnRequirementErrors return OsvvmOptionsType ;
    impure function GetAlertLogReportHierarchy      return OsvvmOptionsType ;
    impure function GetAlertLogFoundReportHier      return boolean ;
    impure function GetAlertLogFoundAlertHier       return boolean ;
    impure function GetAlertLogWriteAlertErrorCount return OsvvmOptionsType ;
    impure function GetAlertLogWriteAlertLevel      return OsvvmOptionsType ;
    impure function GetAlertLogWriteAlertName       return OsvvmOptionsType ;
    impure function GetAlertLogWriteAlertTime       return OsvvmOptionsType ;
    impure function GetAlertLogWriteLogErrorCount   return OsvvmOptionsType ;
    impure function GetAlertLogWriteLogLevel        return OsvvmOptionsType ;
    impure function GetAlertLogWriteLogName         return OsvvmOptionsType ;
    impure function GetAlertLogWriteLogTime         return OsvvmOptionsType ;
    impure function GetAlertLogPrintPassed          return OsvvmOptionsType ;
    impure function GetAlertLogPrintAffirmations    return OsvvmOptionsType ;
    impure function GetAlertLogPrintDisabledAlerts  return OsvvmOptionsType ;
    impure function GetAlertLogPrintRequirements    return OsvvmOptionsType ;
    impure function GetAlertLogPrintIfHaveRequirements  return OsvvmOptionsType ;
    impure function GetAlertLogDefaultPassedGoal    return integer ;

    impure function GetAlertLogAlertPrefix          return string ;
    impure function GetAlertLogLogPrefix            return string ;

    impure function GetAlertLogReportPrefix return string ;
    impure function GetAlertLogDoneName return string ;
    impure function GetAlertLogPassName return string ;
    impure function GetAlertLogFailName return string ;

    impure function GetAlertLogWriteTimeLast        return OsvvmOptionsType ;

  end  protected AlertLogStructPType ;

  --- ///////////////////////////////////////////////////////////////////////////

  type AlertLogStructPType is protected body

    variable GlobalAlertEnabledVar     : boolean := TRUE ; -- Allows turn off and on

    variable AffirmCheckCountVar       : natural := 0 ;
    variable PassedCountVar            : natural := 0 ;

    variable ErrorCount                : integer := 0 ;
    variable AlertCount                : AlertCountType := (0, 0, 0) ;
    
    ------------------------------------------------------------
    type AlertLogRecType is record
    ------------------------------------------------------------
      Name                : Line ;
      NameLower           : Line ;
      Prefix              : Line ;
      Suffix              : Line ;
      ParentID            : AlertLogIDType ;
      ParentIDSet         : Boolean ;
      SiblingID           : AlertLogIDType ;
      ChildID             : AlertLogIDType ;
      ChildIDLast         : AlertLogIDType ;
      AlertCount          : AlertCountType ;
      DisabledAlertCount  : AlertCountType ;
      PassedCount         : Integer ;
      AffirmCount         : Integer ;
      PassedGoal          : Integer ;
      PassedGoalSet       : Boolean ;
      AlertStopCount      : AlertCountType ;
      AlertPrintCount     : AlertCountType ;
      AlertEnabled        : AlertEnableType ;
      LogEnabled          : LogEnableType ;
      ReportMode          : AlertLogReportModeType ;
      PrintParent         : AlertLogPrintParentType ;
      -- Used only by ReadTestSummaries
      TotalErrors         : integer ;
      AffirmPassedCount   : integer ;
--      IsRequirment        : boolean ;
    end record AlertLogRecType ;

    ------------------------------------------------------------
    -- Basis for AlertLog Data Structure
    variable NumAlertLogIDsVar          : AlertLogIDType := 0 ; -- defined by initialize
    variable NumAllocatedAlertLogIDsVar : AlertLogIDType := 0 ;

    type AlertLogRecPtrType   is access AlertLogRecType ;
    type AlertLogArrayType    is array (AlertLogIDType range <>) of AlertLogRecPtrType ;
    type AlertLogArrayPtrType is access AlertLogArrayType ;
    variable AlertLogPtr  : AlertLogArrayPtrType ;

    ------------------------------------------------------------
    -- Report formatting settings, with defaults
    variable PrintPassedVar              : boolean := TRUE ;
    variable PrintAffirmationsVar        : boolean := FALSE ;
    variable PrintDisabledAlertsVar      : boolean := FALSE ;
    variable PrintRequirementsVar        : boolean := FALSE ;
    variable HasRequirementsVar          : boolean := FALSE ;
    variable PrintIfHaveRequirementsVar  : boolean := TRUE ;

    variable DefaultPassedGoalVar        : integer := 1 ;

    variable FailOnWarningVar            : boolean := TRUE ;
    variable FailOnDisabledErrorsVar     : boolean := TRUE ;
    variable FailOnRequirementErrorsVar  : boolean := TRUE ;

    variable ReportHierarchyVar          : boolean := TRUE ;
    variable FoundReportHierVar          : boolean := FALSE ;
    variable FoundAlertHierVar           : boolean := FALSE ;

    variable WriteAlertErrorCountVar     : boolean := FALSE ;
    variable WriteAlertLevelVar          : boolean := TRUE ;
    variable WriteAlertNameVar           : boolean := TRUE ;
    variable WriteAlertTimeVar           : boolean := TRUE ;
    variable WriteLogErrorCountVar       : boolean := FALSE ;
    variable WriteLogLevelVar            : boolean := TRUE ;
    variable WriteLogNameVar             : boolean := TRUE ;
    variable WriteLogTimeVar             : boolean := TRUE ;

    variable AlertPrefixVar              : NamePType ;
    variable LogPrefixVar                : NamePType ;
    variable ReportPrefixVar             : NamePType ;
    variable DoneNameVar                 : NamePType ;
    variable PassNameVar                 : NamePType ;
    variable FailNameVar                 : NamePType ;
    variable IdSeparatorVar              : NamePType ;

    variable AlertLogJustifyAmountVar    : integer := 0 ;
    variable ReportJustifyAmountVar      : integer := 0 ;
    variable TimeJustifyAmountVar        : integer := 0 ;
    
    variable WriteTimeLastVar            : boolean := TRUE ;

    ------------------------------------------------------------
    -- PT Local
    impure function VerifyID(
      AlertLogID : AlertLogIDType ;
      LowestID   : AlertLogIDType := ALERTLOG_BASE_ID ;
      InvalidID  : AlertLogIDType := ALERTLOG_DEFAULT_ID
    ) return AlertLogIDType is
    ------------------------------------------------------------
    begin
      if AlertLogID < LowestID or AlertLogID > NumAlertLogIDsVar then
        Alert("Invalid AlertLogID") ;
        return InvalidID ;
      else
        return AlertLogID ;
      end if ;
    end function VerifyID ;

    ------------------------------------------------------------
    procedure IncAffirmCount(AlertLogID : AlertLogIDType) is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      if GlobalAlertEnabledVar then
        localAlertLogID := VerifyID(AlertLogID) ;
        AlertLogPtr(localAlertLogID).AffirmCount := AlertLogPtr(localAlertLogID).AffirmCount + 1 ;
        AffirmCheckCountVar := AffirmCheckCountVar + 1 ;
      end if ;
    end procedure IncAffirmCount ;

    ------------------------------------------------------------
    impure function GetAffirmCount return natural is
    ------------------------------------------------------------
    begin
      return AffirmCheckCountVar ;
    end function GetAffirmCount ;

    ------------------------------------------------------------
    procedure IncAffirmPassedCount(AlertLogID : AlertLogIDType) is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      if GlobalAlertEnabledVar then
        localAlertLogID := VerifyID(AlertLogID) ;
        AlertLogPtr(localAlertLogID).PassedCount := AlertLogPtr(localAlertLogID).PassedCount + 1 ;
        PassedCountVar := PassedCountVar + 1 ;
        AlertLogPtr(localAlertLogID).AffirmCount := AlertLogPtr(localAlertLogID).AffirmCount + 1 ;
        AffirmCheckCountVar := AffirmCheckCountVar + 1 ;
      end if ;
    end procedure IncAffirmPassedCount ;

    ------------------------------------------------------------
    impure function GetAffirmPassedCount return natural is
    ------------------------------------------------------------
    begin
      return PassedCountVar ;
    end function GetAffirmPassedCount ;

    ------------------------------------------------------------
    -- PT Local
    procedure IncrementAlertCount(
    ------------------------------------------------------------
      constant AlertLogID        : in    AlertLogIDType ;
      constant Level             : in    AlertType ;
      variable StopDueToCount    : inout boolean ;
      variable IncrementByAmount : in    integer := 1
    ) is
    begin
      if AlertLogPtr(AlertLogID).AlertEnabled(Level) then
        AlertLogPtr(AlertLogID).AlertCount(Level) := AlertLogPtr(AlertLogID).AlertCount(Level) + IncrementByAmount ;
        -- Exceeded Stop Count at this level?
        if AlertLogPtr(AlertLogID).AlertCount(Level) >= AlertLogPtr(AlertLogID).AlertStopCount(Level) then
          StopDueToCount := TRUE ;
        end if ;
        -- Propagate counts to parent(s)  -- Ascend Hierarchy
        if AlertLogID /= ALERTLOG_BASE_ID then
          IncrementAlertCount(AlertLogPtr(AlertLogID).ParentID, Level, StopDueToCount, IncrementByAmount) ;
        end if ;
      else
        -- Disabled, increment disabled count
        AlertLogPtr(AlertLogID).DisabledAlertCount(Level) := AlertLogPtr(AlertLogID).DisabledAlertCount(Level) + IncrementByAmount ;
      end if ;
    end procedure IncrementAlertCount ;
    
    ------------------------------------------------------------
    -- PT Local
    procedure LocalPrint (
    ------------------------------------------------------------
      AlertLogID      : AlertLogIDType ;
      AlertLogName    : string ; 
      WriteErrorCount : boolean ; 
      WriteLevel      : boolean ; 
      LevelName       : string ; 
      WriteName       : boolean ; 
      Message         : string ;
      WriteTime       : boolean
    ) is
      variable buf : line ;
      variable ParentID : AlertLogIDType ;
    begin
      write(buf, ResolveOsvvmWritePrefix(ReportPrefixVar.GetOpt) ) ; -- Print  
      -- Debug Mode
      if WriteErrorCount then
        if ErrorCount > 0 then
          write(buf, justify(to_string(ErrorCount), RIGHT, 3) & "  ") ;
        else
          swrite(buf, "     ") ;
        end if ;
      end if ;
      -- Write Time
      if WriteTime and not WriteTimeLastVar then
--        write(buf, justify(to_string(NOW, 1 ns), TimeJustifyAmountVar, RIGHT) & "    ") ;
        write(buf, justify(to_string(NOW, GetOsvvmDefaultTimeUnits), TimeJustifyAmountVar, RIGHT) & "    ") ;
      end if ;
      -- Alert or Log
      write(buf, AlertLogName) ;
      -- Level Name, when enabled (default)
      if WriteLevel then
        write(buf, "  " & LevelName) ;
      end if ;
      -- AlertLog Name
      if FoundAlertHierVar and WriteName then
        if AlertLogPtr(AlertLogID).PrintParent = PRINT_NAME then
          write(buf, "   in " & LeftJustify(AlertLogPtr(AlertLogID).Name.all & ',', AlertLogJustifyAmountVar) ) ;
        else
          ParentID := AlertLogPtr(AlertLogID).ParentID ;
          write(buf, "   in " & LeftJustify(AlertLogPtr(ParentID).Name.all & ResolveOsvvmIdSeparator(IdSeparatorVar.GetOpt) &
            AlertLogPtr(AlertLogID).Name.all & ',', AlertLogJustifyAmountVar) ) ;
        end if ;
      end if ;
      -- Spacing before message
      swrite(buf, "  ") ;
      -- Prefix
      if AlertLogPtr(AlertLogID).Prefix /= NULL then
        write(buf, ' ' & AlertLogPtr(AlertLogID).Prefix.all) ;
      end if ;
      -- Message
      write(buf, " " & Message) ;
      -- Suffix
      if AlertLogPtr(AlertLogID).Suffix /= NULL then
        write(buf, ' ' & AlertLogPtr(AlertLogID).Suffix.all) ;
      end if ;
      -- Time Last
      if WriteTime and WriteTimeLastVar then
--        write(buf, " at " & to_string(NOW, 1 ns)) ;
        write(buf, " at " & to_string(NOW, GetOsvvmDefaultTimeUnits)) ;
      end if ;
      writeline(buf) ;
    end procedure LocalPrint ;
    
    ------------------------------------------------------------
    procedure alert (
    ------------------------------------------------------------
      AlertLogID   : AlertLogIDType ;
      message      : string ;
      level        : AlertType := ERROR
    ) is
      variable buf : Line ;
      -- constant AlertPrefix : string := AlertPrefixVar.Get(OSVVM_DEFAULT_ALERT_PREFIX) ;
      variable StopDueToCount  : boolean := FALSE ;
      variable localAlertLogID : AlertLogIDType ;
    begin
      -- Only write and count when GlobalAlertEnabledVar is enabled
      if GlobalAlertEnabledVar then
        localAlertLogID := VerifyID(AlertLogID) ;
        
        -- Always Count (before printing so have current ErrorCount
        IncrementAlertCount(localAlertLogID, Level, StopDueToCount) ;
        AlertCount := AlertLogPtr(ALERTLOG_BASE_ID).AlertCount;
        ErrorCount := SumAlertCount(AlertCount);
        
         -- Write when Alert is Enabled
        if AlertLogPtr(localAlertLogID).AlertEnabled(Level) and (AlertLogPtr(localAlertLogID).AlertCount(Level) <= AlertLogPtr(localAlertLogID).AlertPrintCount(Level)) then
          LocalPrint(
            AlertLogID       => localAlertLogID,
            AlertLogName     => AlertPrefixVar.Get(OSVVM_DEFAULT_ALERT_PREFIX),  
            WriteErrorCount  => WriteAlertErrorCountVar,
            WriteLevel       => WriteAlertLevelVar,
            LevelName        => ALERT_NAME(Level),
            WriteName        => WriteAlertNameVar,
            Message          => Message,
            WriteTime        => WriteAlertTimeVar 
          ) ;
        end if ;
        
        if StopDueToCount then
--          write(buf, LF & AlertPrefix & " Stop Count on " & ALERT_NAME(Level) & " reached") ;
          write(buf, LF & ResolveOsvvmWritePrefix(ReportPrefixVar.GetOpt) & 
            AlertPrefixVar.Get(OSVVM_DEFAULT_ALERT_PREFIX) & " Stop Count on " & 
            ALERT_NAME(Level) & " reached") ;
          if FoundAlertHierVar then
            write(buf, " in " & AlertLogPtr(localAlertLogID).Name.all) ;
          end if ;
          write(buf, " at " & to_string(NOW, 1 ns) & " ") ;
          writeline(buf) ;
          ReportAlerts(ReportWhenZero => TRUE) ;
          if FileExists(OSVVM_BUILD_YAML_FILE) then
--          work.ReportPkg.EndOfTestReports ;  -- creates circular package issues
            WriteAlertSummaryYaml(
              FileName        => OSVVM_BUILD_YAML_FILE
            ) ;
            WriteAlertYaml (
              FileName        => OSVVM_OUTPUT_DIRECTORY & GetAlertLogName(ALERTLOG_BASE_ID) & "_alerts.yml"
            ) ;
          end if ;
          std.env.stop(ErrorCount) ;
        end if ;
      end if ;
    end procedure alert ;

    ------------------------------------------------------------
    procedure IncAlertCount (
    ------------------------------------------------------------
      AlertLogID   : AlertLogIDType ;
      level        : AlertType := ERROR
    ) is
      variable buf : Line ;
      -- constant AlertPrefix : string := AlertPrefixVar.Get(OSVVM_DEFAULT_ALERT_PREFIX) ;
      variable StopDueToCount : boolean := FALSE ;
      variable localAlertLogID : AlertLogIDType ;
    begin
      if GlobalAlertEnabledVar then
        localAlertLogID := VerifyID(AlertLogID) ;
        IncrementAlertCount(localAlertLogID, Level, StopDueToCount) ;
        AlertCount := AlertLogPtr(ALERTLOG_BASE_ID).AlertCount;
        ErrorCount := SumAlertCount(AlertCount);
        if StopDueToCount then
--          write(buf, LF & AlertPrefix & " Stop Count on " & ALERT_NAME(Level) & " reached") ;
          write(buf, LF & AlertPrefixVar.Get(OSVVM_DEFAULT_ALERT_PREFIX) & " Stop Count on " & ALERT_NAME(Level) & " reached") ;
          if FoundAlertHierVar then
            write(buf, " in " & AlertLogPtr(localAlertLogID).Name.all) ;
          end if ;
          write(buf, " at " & to_string(NOW, 1 ns) & " ") ;
          writeline(buf) ;
          ReportAlerts(ReportWhenZero => TRUE) ;
          std.env.stop(ErrorCount) ;
        end if ;
      end if ;
    end procedure IncAlertCount ;

    ------------------------------------------------------------
    -- PT Local
    impure function CalcJustify (AlertLogID : AlertLogIDType; CurrentLength : integer; IndentAmount : integer; IdSeparatorLength : integer) return integer_vector is
    ------------------------------------------------------------
      variable ResultValues, LowerLevelValues : integer_vector(1 to 2) ;  -- 1 = Max, 2 = Indented
      variable CurID, ParentID : AlertLogIDType ;
      variable ParentNameLen   : integer ;
    begin
      ResultValues(1) := CurrentLength + 1 ;            -- AlertLogJustifyAmountVar
      ResultValues(2) := CurrentLength + IndentAmount ; -- ReportJustifyAmountVar
      if AlertLogPtr(AlertLogID).PrintParent = PRINT_NAME_AND_PARENT then
        ParentID := AlertLogPtr(AlertLogID).ParentID ;
        ParentNameLen := AlertLogPtr(ParentID).Name'length ;
        ResultValues(1) := IdSeparatorLength + ParentNameLen + ResultValues(1) ;  -- AlertLogJustifyAmountVar
--        ResultValues(2) := IdSeparatorLength + ParentNameLen + ResultValues(2) ;  -- ReportJustifyAmountVar
      end if ;
      CurID := AlertLogPtr(AlertLogID).ChildID ;
      while CurID > ALERTLOG_BASE_ID loop
        if CurID = REQUIREMENT_ALERTLOG_ID and HasRequirementsVar = FALSE then
          CurID := AlertLogPtr(CurID).SiblingID ;
          next ;
        end if ;
        LowerLevelValues := CalcJustify(CurID, AlertLogPtr(CurID).Name'length, IndentAmount + 2, IdSeparatorLength) ;
        ResultValues(1)  := maximum(ResultValues(1), LowerLevelValues(1)) ;
        if AlertLogPtr(AlertLogID).ReportMode /= DISABLED then
          ResultValues(2)  := maximum(ResultValues(2), LowerLevelValues(2)) ;
        end if ;
        CurID := AlertLogPtr(CurID).SiblingID ;
      end loop ;
      return ResultValues ;
    end function CalcJustify ;

    ------------------------------------------------------------
    procedure SetJustify (
    ------------------------------------------------------------
      Enable      : boolean := TRUE ;
      AlertLogID  : AlertLogIDType := ALERTLOG_BASE_ID
    ) is
      constant Separator : string := ResolveOsvvmIdSeparator(IdSeparatorVar.GetOpt) ;
    begin
      if Enable then
        (AlertLogJustifyAmountVar, ReportJustifyAmountVar) := CalcJustify(AlertLogID, 0, 0, Separator'length) ;
      else
        AlertLogJustifyAmountVar := 0 ;
        ReportJustifyAmountVar   := 0 ;
      end if;
    end procedure SetJustify ;

    ------------------------------------------------------------
    impure function GetAlertCount(AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID) return AlertCountType is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      return AlertLogPtr(localAlertLogID).AlertCount ;
    end function GetAlertCount ;

    ------------------------------------------------------------
    -- Local
    impure function RemoveNonFailingWarnings(A : AlertCountType) return AlertCountType is
    ------------------------------------------------------------
      variable Count : AlertCountType ;
    begin
      Count := A ;
      if not FailOnWarningVar then
        Count(WARNING) := 0 ;
      end if ;
      return Count ;
    end function RemoveNonFailingWarnings ;

    ------------------------------------------------------------
    impure function GetEnabledAlertCount(AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID) return AlertCountType is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
      variable Count : AlertCountType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      return RemoveNonFailingWarnings( AlertLogPtr(localAlertLogID).AlertCount ) ;
    end function GetEnabledAlertCount ;


    ------------------------------------------------------------
    impure function GetDisabledAlertCount return AlertCountType is
    ------------------------------------------------------------
      variable Count : AlertCountType := (others => 0) ;
    begin
      for i in ALERTLOG_BASE_ID to NumAlertLogIDsVar loop
        Count := Count + AlertLogPtr(i).DisabledAlertCount ;
--? Should excluded warnings get counted as disabled errors?
--?        if not FailOnWarningVar then
--?          Count(WARNING) := Count(WARNING) + AlertLogPtr(i).AlertCount(WARNING) ;
--?        end if ;
      end loop ;
      return Count ;
    end function GetDisabledAlertCount ;

    ------------------------------------------------------------
    impure function LocalGetDisabledAlertCount(AlertLogID: AlertLogIDType) return AlertCountType is
    ------------------------------------------------------------
      variable Count : AlertCountType ;
      variable CurID : AlertLogIDType ;
    begin
      Count := AlertLogPtr(AlertLogID).DisabledAlertCount ;
      -- Find Children of this ID
      CurID := AlertLogPtr(AlertLogID).ChildID ;
      while CurID > ALERTLOG_BASE_ID loop
        Count := Count + LocalGetDisabledAlertCount(CurID) ; -- Recursively descend into children
        CurID := AlertLogPtr(CurID).SiblingID ;
      end loop ;
      return Count ;
    end function LocalGetDisabledAlertCount ;

    ------------------------------------------------------------
    impure function GetDisabledAlertCount(AlertLogID: AlertLogIDType) return AlertCountType is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      return LocalGetDisabledAlertCount(localAlertLogID) ;
    end function GetDisabledAlertCount ;

    ------------------------------------------------------------
    -- Local  GetRequirementsCount
    --    Each bin contains a separate requirement
    --    RequirementsGoal   = # of bins with PassedGoal > 0
    --    RequirementsPassed = # bins with PassedGoal > 0 and PassedCount > PassedGoal
    procedure GetRequirementsCount(
      AlertLogID              : AlertLogIDType;
      RequirementsPassed      : out integer ;
      RequirementsGoal        : out integer
    )  is
    ------------------------------------------------------------
      variable ChildRequirementsPassed, ChildRequirementsGoal  : integer ;
      variable CurID : AlertLogIDType ;
    begin
      RequirementsPassed := 0 ;
      RequirementsGoal   := 0 ;
      if AlertLogPtr(AlertLogID).PassedGoal > 0 then
        RequirementsGoal := 1 ;
        if AlertLogPtr(AlertLogID).PassedCount >= AlertLogPtr(AlertLogID).PassedGoal then
          RequirementsPassed := 1 ;
        end if ;
      end if ;
      -- Find Children of this ID
      CurID := AlertLogPtr(AlertLogID).ChildID ;
      while CurID > ALERTLOG_BASE_ID loop
        GetRequirementsCount(CurID, ChildRequirementsPassed, ChildRequirementsGoal) ;
        RequirementsPassed := RequirementsPassed + ChildRequirementsPassed ;
        RequirementsGoal   := RequirementsGoal   + ChildRequirementsGoal ;
        CurID := AlertLogPtr(CurID).SiblingID ;
      end loop ;
    end procedure GetRequirementsCount ;

    ------------------------------------------------------------
-- Only used at top level and superceded by variables PassedCountVar AffirmCheckCountVar
    -- Local
    procedure GetPassedAffirmCount(
      AlertLogID       : AlertLogIDType;
      PassedCount      : out integer ;
      AffirmCount      : out integer
    )  is
    ------------------------------------------------------------
      variable ChildPassedCount, ChildAffirmCount  : integer ;
      variable CurID : AlertLogIDType ;
    begin
      PassedCount   := AlertLogPtr(AlertLogID).PassedCount ;
      AffirmCount   := AlertLogPtr(AlertLogID).AffirmCount ;
      -- Find Children of this ID
      CurID := AlertLogPtr(AlertLogID).ChildID ;
      while CurID > ALERTLOG_BASE_ID loop
        GetPassedAffirmCount(CurID, ChildPassedCount, ChildAffirmCount) ;
        PassedCount := PassedCount + ChildPassedCount ;
        AffirmCount := AffirmCount + ChildAffirmCount ;
        CurID := AlertLogPtr(CurID).SiblingID ;
      end loop ;
    end procedure GetPassedAffirmCount ;

    ------------------------------------------------------------
    -- Local
    procedure CalcTopTotalErrors (
    ------------------------------------------------------------
      constant ExternalErrors           : in  AlertCountType ;
      variable TotalErrors              : out integer ;
      variable TotalAlertCount          : out AlertCountType ;
      variable TotalRequirementsPassed  : out integer ;
      variable TotalRequirementsCount   : out integer
    ) is
      variable DisabledAlertCount : AlertCountType ;
      variable TotalAlertErrors, TotalDisabledAlertErrors : integer ;
      variable TotalRequirementErrors : integer ;
    begin
      TotalAlertCount        := AlertLogPtr(ALERTLOG_BASE_ID).AlertCount + ExternalErrors ;
      TotalAlertErrors       := SumAlertCount( RemoveNonFailingWarnings(TotalAlertCount)) ;
      TotalErrors            := TotalAlertErrors ;

      DisabledAlertCount        := GetDisabledAlertCount(ALERTLOG_BASE_ID) ;
      TotalDisabledAlertErrors  := SumAlertCount( RemoveNonFailingWarnings(DisabledAlertCount) ) ;
      if FailOnDisabledErrorsVar then
        TotalAlertCount := TotalAlertCount + DisabledAlertCount ;
        TotalErrors := TotalErrors + TotalDisabledAlertErrors ;
      end if ;

      -- Perspective, 1 requirement per bin
      GetRequirementsCount(ALERTLOG_BASE_ID, TotalRequirementsPassed, TotalRequirementsCount) ;
      TotalRequirementErrors := TotalRequirementsCount - TotalRequirementsPassed ;
      if FailOnRequirementErrorsVar then
        TotalErrors := TotalErrors + TotalRequirementErrors ;
      end if ;

      -- Set AffirmCount for top level
      AlertLogPtr(ALERTLOG_BASE_ID).PassedCount := PassedCountVar ;
      AlertLogPtr(ALERTLOG_BASE_ID).AffirmCount := AffirmCheckCountVar ;
    end procedure CalcTopTotalErrors ;

    ------------------------------------------------------------
    -- Local
    impure function CalcTotalErrors (AlertLogID : AlertLogIDType) return integer is
    ------------------------------------------------------------
      variable TotalErrors : integer ;
      variable TotalAlertCount, DisabledAlertCount : AlertCountType ;
      variable TotalAlertErrors, TotalDisabledAlertErrors : integer ;
      variable TotalRequirementErrors : integer ;
      variable TotalRequirementsPassed, TotalRequirementsCount : integer ;
    begin
      TotalAlertCount        := AlertLogPtr(AlertLogID).AlertCount ;
      TotalAlertErrors       := SumAlertCount( RemoveNonFailingWarnings(TotalAlertCount)) ;
      TotalErrors            := TotalAlertErrors ;

      DisabledAlertCount        := GetDisabledAlertCount(AlertLogID) ;
      TotalDisabledAlertErrors  := SumAlertCount( RemoveNonFailingWarnings(DisabledAlertCount) ) ;
      if FailOnDisabledErrorsVar then
        TotalErrors := TotalErrors + TotalDisabledAlertErrors ;
      end if ;

      -- Perspective, 1 requirement per bin
      GetRequirementsCount(AlertLogID, TotalRequirementsPassed, TotalRequirementsCount) ;
      TotalRequirementErrors := TotalRequirementsCount - TotalRequirementsPassed ;
      if FailOnRequirementErrorsVar then
        TotalErrors := TotalErrors + TotalRequirementErrors ;
      end if ;

      return TotalErrors ;
    end function CalcTotalErrors ;

    ------------------------------------------------------------
    -- PT Local
    procedure PrintTopAlerts (
    ------------------------------------------------------------
      AlertLogID                  : AlertLogIDType ;
      Name                        : string ;
      ExternalErrors              : AlertCountType ;
      variable HasDisabledAlerts  : inout Boolean ;
      variable TestFailed         : inout Boolean
    ) is
--      constant ReportPrefix    : string := ResolveOsvvmWritePrefix(ReportPrefixVar.GetOpt ) ;
--      constant DoneName        : string := ResolveOsvvmDoneName(DoneNameVar.GetOpt     ) ;
--      constant PassName        : string := ResolveOsvvmPassName(PassNameVar.GetOpt     ) ;
--      constant FailName        : string := ResolveOsvvmFailName(FailNameVar.GetOpt     ) ;
      variable buf : line ;
      variable TotalErrors : integer ;
      variable TotalAlertErrors, TotalDisabledAlertErrors : integer ;
      variable TotalRequirementsPassed, TotalRequirementsGoal, TotalRequirementErrors : integer ;
      variable AlertCountVar, DisabledAlertCount : AlertCountType ;
      variable PassedCount, AffirmCheckCount : integer ;
    begin
--!!
--!! Update to use CalcTopTotalErrors
--!!
      AlertCountVar     := AlertLogPtr(AlertLogID).AlertCount + ExternalErrors ;
      TotalAlertErrors  := SumAlertCount( RemoveNonFailingWarnings(AlertCountVar)) ;

      DisabledAlertCount        := GetDisabledAlertCount(AlertLogID) ;
      TotalDisabledAlertErrors  := SumAlertCount( RemoveNonFailingWarnings(DisabledAlertCount) ) ;
      HasDisabledAlerts         := TotalDisabledAlertErrors /= 0 ;

      GetRequirementsCount(AlertLogID, TotalRequirementsPassed, TotalRequirementsGoal) ;
      TotalRequirementErrors := TotalRequirementsGoal - TotalRequirementsPassed ;

      TotalErrors := TotalAlertErrors ;
      if FailOnDisabledErrorsVar then
        TotalErrors := TotalErrors + TotalDisabledAlertErrors ;
      end if ;
      if FailOnRequirementErrorsVar then
        TotalErrors := TotalErrors + TotalRequirementErrors ;
      end if ;

      TestFailed := TotalErrors /= 0 ;

      GetPassedAffirmCount(AlertLogID, PassedCount, AffirmCheckCount) ;

      write(buf, ResolveOsvvmWritePrefix(ReportPrefixVar.GetOpt)) ;
      if not WriteTimeLastVar then
        write(buf, justify(to_string(NOW, 1 ns), TimeJustifyAmountVar, RIGHT) & "    ") ;
      end if ;

      if not TestFailed then
        write(buf, 
          ResolveOsvvmDoneName(DoneNameVar.GetOpt) & "   " &  -- DoneName
          ResolveOsvvmPassName(PassNameVar.GetOpt) & "   " &  -- PassName
          Name
        ) ;
      else
        write(buf,
          ResolveOsvvmDoneName(DoneNameVar.GetOpt) & "   " &  -- DoneName
          ResolveOsvvmFailName(FailNameVar.GetOpt) & "   " &  -- FailName
          Name
        ) ;
      end if ;
--?  Also print when warnings exist and are hidden by FailOnWarningVar=FALSE
      if TestFailed then
        write(buf, "  Total Error(s) = " & to_string(TotalErrors) ) ;
        write(buf, "  Failures: "        & to_string(AlertCountVar(FAILURE)) ) ;
        write(buf, "  Errors: "          & to_string(AlertCountVar(ERROR) ) ) ;
        write(buf, "  Warnings: "        & to_string(AlertCountVar(WARNING) ) ) ;
      end if ;
      if HasDisabledAlerts or PrintDisabledAlertsVar then   -- print if exist or enabled
          write(buf, "   Total Disabled Error(s) = " & to_string(TotalDisabledAlertErrors)) ;
      end if ;
      if (HasDisabledAlerts and FailOnDisabledErrorsVar) or PrintDisabledAlertsVar then  -- print if enabled
        write(buf, "  Failures: "  & to_string(DisabledAlertCount(FAILURE)) ) ;
        write(buf, "  Errors: "    & to_string(DisabledAlertCount(ERROR) ) ) ;
        write(buf, "  Warnings: "  & to_string(DisabledAlertCount(WARNING) ) ) ;
      end if ;
      if PrintPassedVar or (AffirmCheckCount /= 0) or PrintAffirmationsVar then -- Print if passed or printing affirmations
        write(buf, "  Passed: " & to_string(PassedCount)) ;
      end if;
      if (AffirmCheckCount /= 0) or PrintAffirmationsVar then
        write(buf, "  Affirmations Checked: " & to_string(AffirmCheckCount)) ;
      end if ;
      if  PrintRequirementsVar or
          (PrintIfHaveRequirementsVar and HasRequirementsVar) or
          (FailOnRequirementErrorsVar and TotalRequirementErrors /= 0)
      then
        write(buf, "  Requirements Passed: " & to_string(TotalRequirementsPassed) &
                   " of " & to_string(TotalRequirementsGoal) ) ;
      end if ;
      if WriteTimeLastVar then
        write(buf, "  at " & to_string(NOW, 1 ns)) ;
      end if ;
      WriteLine(buf) ;
    end procedure PrintTopAlerts ;

    ------------------------------------------------------------
    -- PT Local
    procedure PrintOneChild(
    ------------------------------------------------------------
      AlertLogID        : AlertLogIDType ;
      Prefix            : string ;
      IndentAmount      : integer ;
      ReportWhenZero    : boolean ;
      HasErrors         : boolean ;
      HasDisabledErrors : boolean
    ) is
      variable buf : line ;
      alias CurID  : AlertLogIDType is AlertLogID ;
    begin
      if ReportWhenZero or HasErrors then
        write(buf, Prefix &  " "   & LeftJustify(AlertLogPtr(CurID).Name.all, ReportJustifyAmountVar - IndentAmount)) ;
        write(buf, "  Failures: "  & to_string(AlertLogPtr(CurID).AlertCount(FAILURE) ) ) ;
        write(buf, "  Errors: "    & to_string(AlertLogPtr(CurID).AlertCount(ERROR) ) ) ;
        write(buf, "  Warnings: "  & to_string(AlertLogPtr(CurID).AlertCount(WARNING) ) ) ;
        if (HasDisabledErrors and FailOnDisabledErrorsVar) or PrintDisabledAlertsVar then
          write(buf, "  Disabled Failures: "  & to_string(AlertLogPtr(CurID).DisabledAlertCount(FAILURE) ) ) ;
          write(buf, "  Errors: "    & to_string(AlertLogPtr(CurID).DisabledAlertCount(ERROR) ) ) ;
          write(buf, "  Warnings: "  & to_string(AlertLogPtr(CurID).DisabledAlertCount(WARNING) ) ) ;
        end if ;
        if PrintPassedVar or PrintRequirementsVar then
          write(buf, "  Passed: " & to_string(AlertLogPtr(CurID).PassedCount)) ;
        end if;
        if PrintRequirementsVar then
          write(buf, " of " & to_string(AlertLogPtr(CurID).PassedGoal) ) ;
        end if ;
        if PrintAffirmationsVar then
          write(buf, "  Affirmations: "  & to_string(AlertLogPtr(CurID).AffirmCount ) ) ;
        end if ;
        WriteLine(buf) ;
      end if ;
    end procedure PrintOneChild ;

    ------------------------------------------------------------
    -- PT Local
    procedure IterateAndPrintChildren(
    ------------------------------------------------------------
      AlertLogID        : AlertLogIDType ;
      Prefix            : string ;
      IndentAmount      : integer ;
      ReportWhenZero    : boolean ;
      HasDisabledErrors : boolean
    ) is
      variable buf : line ;
      variable CurID : AlertLogIDType ;
      variable HasErrors : boolean ;
    begin
      CurID := AlertLogPtr(AlertLogID).ChildID ;
      while CurID > ALERTLOG_BASE_ID loop
        -- Don't print requirements if there no requirements
        if CurID = REQUIREMENT_ALERTLOG_ID and HasRequirementsVar = FALSE then
          CurID := AlertLogPtr(CurID).SiblingID ;
          next ;
        end if ;
        HasErrors :=
          (SumAlertCount(AlertLogPtr(CurID).AlertCount) > 0) or
          (FailOnDisabledErrorsVar and (SumAlertCount(AlertLogPtr(CurID).DisabledAlertCount) > 0)) or
          (FailOnRequirementErrorsVar and (AlertLogPtr(CurID).PassedCount < AlertLogPtr(CurID).PassedGoal)) ;

        if AlertLogPtr(CurID).ReportMode = ENABLED or (AlertLogPtr(CurID).ReportMode = NONZERO and HasErrors) then
          PrintOneChild(
            AlertLogID         => CurID,
            Prefix             => Prefix,
            IndentAmount       => IndentAmount,
            ReportWhenZero     => ReportWhenZero,
            HasErrors          => HasErrors,
            HasDisabledErrors  => HasDisabledErrors
          ) ;
          IterateAndPrintChildren(
            AlertLogID         => CurID,
            Prefix             => Prefix & "  ",
            IndentAmount       => IndentAmount + 2,
            ReportWhenZero     => ReportWhenZero,
            HasDisabledErrors  => HasDisabledErrors
          ) ;
        end if ;
        CurID := AlertLogPtr(CurID).SiblingID ;
      end loop ;
    end procedure IterateAndPrintChildren ;

    ------------------------------------------------------------
    procedure ReportAlerts (
      Name           : string := OSVVM_STRING_INIT_PARM_DETECT ;
      AlertLogID     : AlertLogIDType := ALERTLOG_BASE_ID ;
      ExternalErrors : AlertCountType := (0,0,0) ;
      ReportAll      : boolean := FALSE ;
      ReportWhenZero : boolean := TRUE
    ) is
    ------------------------------------------------------------
      variable TestFailed, HasDisabledErrors : boolean ;
      -- constant ReportPrefix : string := ResolveOsvvmWritePrefix(ReportPrefixVar.GetOpt) ;
      variable TurnedOnJustify : boolean := FALSE ;
      variable localAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      if ReportJustifyAmountVar <= 0 then
        TurnedOnJustify := TRUE ;
        SetJustify ;
      end if ;

      if IsOsvvmStringSet(Name) then
        PrintTopAlerts (
          AlertLogID         => localAlertLogID,
          Name               => Name,
          ExternalErrors     => ExternalErrors,
          HasDisabledAlerts  => HasDisabledErrors,
          TestFailed         => TestFailed
        ) ;
      else
        PrintTopAlerts (
          AlertLogID         => localAlertLogID,
          Name               => AlertLogPtr(localAlertLogID).Name.all,
          ExternalErrors     => ExternalErrors,
          HasDisabledAlerts  => HasDisabledErrors,
          TestFailed         => TestFailed
        ) ;
      end if ;
      --Print Hierarchy when enabled and test failed
      if ReportAll or (FoundReportHierVar and ReportHierarchyVar and TestFailed) then
      -- (NumErrors /= 0 or (NumDisabledErrors /=0 and FailOnDisabledErrorsVar)) then
        IterateAndPrintChildren(
          AlertLogID         => localAlertLogID,
--          Prefix             => ReportPrefix & "  ",
          Prefix             => ResolveOsvvmWritePrefix(ReportPrefixVar.GetOpt) & "  ",
          IndentAmount       => 2,
          ReportWhenZero     => ReportAll or ReportWhenZero,
          HasDisabledErrors  => HasDisabledErrors -- NumDisabledErrors /= 0
        ) ;
      end if ;
      if TurnedOnJustify then
        -- Turn it back off
        SetJustify(FALSE) ;
      end if ;
    end procedure ReportAlerts ;

    ------------------------------------------------------------
    procedure ReportRequirements is
    ------------------------------------------------------------
      variable TestFailed, HasDisabledErrors : boolean ;
--      constant ReportPrefix : string := ResolveOsvvmWritePrefix(ReportPrefixVar.GetOpt) ;
      variable TurnedOnJustify : boolean := FALSE ;
      variable SavedPrintRequirementsVar : boolean ;
    begin
      SavedPrintRequirementsVar := PrintRequirementsVar ;
      PrintRequirementsVar := TRUE ;

      if ReportJustifyAmountVar <= 0 then
        TurnedOnJustify := TRUE ;
        SetJustify ;
      end if ;
      PrintTopAlerts (
        AlertLogID         => ALERTLOG_BASE_ID,
        Name               => AlertLogPtr(ALERTLOG_BASE_ID).Name.all,
        ExternalErrors     => (0,0,0),
        HasDisabledAlerts  => HasDisabledErrors,
        TestFailed         => TestFailed
      ) ;
      IterateAndPrintChildren(
        AlertLogID         => REQUIREMENT_ALERTLOG_ID,
--        Prefix             => ReportPrefix & "  ",
        Prefix             => ResolveOsvvmWritePrefix(ReportPrefixVar.GetOpt) & "  ",
        IndentAmount       => 2,
        ReportWhenZero     => TRUE,
        HasDisabledErrors  => HasDisabledErrors -- NumDisabledErrors /= 0
      ) ;
      if TurnedOnJustify then
        -- Turn it back off
        SetJustify(FALSE) ;
      end if ;
      PrintRequirementsVar := SavedPrintRequirementsVar ;
    end procedure ReportRequirements ;

    ------------------------------------------------------------
    procedure ReportAlerts ( Name : string ; AlertCount : AlertCountType ) is
    ------------------------------------------------------------
      -- constant ReportPrefix    : string := ResolveOsvvmWritePrefix(ReportPrefixVar.GetOpt ) ;
      -- constant DoneName        : string := ResolveOsvvmDoneName(DoneNameVar.GetOpt     ) ;
      -- constant PassName        : string := ResolveOsvvmPassName(PassNameVar.GetOpt     ) ;
      -- constant FailName        : string := ResolveOsvvmFailName(FailNameVar.GetOpt     ) ;
      variable buf : line ;
      variable NumErrors : integer ;
    begin
      NumErrors := SumAlertCount(AlertCount) ;
      if  NumErrors = 0 then
        -- Passed
        -- write(buf, ReportPrefix & DoneName & "  " & PassName & "  " & Name) ;
        write(buf,
          ResolveOsvvmWritePrefix(ReportPrefixVar.GetOpt ) & -- ReportPrefix
          ResolveOsvvmDoneName(DoneNameVar.GetOpt) & "  " &  -- DoneName
          ResolveOsvvmPassName(PassNameVar.GetOpt) & "  " &  -- PassName
          Name
        ) ;
        write(buf, "  at "  & to_string(NOW, 1 ns)) ;
        WriteLine(buf) ;
      else
        -- Failed
        -- write(buf, ReportPrefix & DoneName & "  " & FailName & "  "& Name) ;
        write(buf,
          ResolveOsvvmWritePrefix(ReportPrefixVar.GetOpt ) & -- ReportPrefix
          ResolveOsvvmDoneName(DoneNameVar.GetOpt) & "  " &  -- DoneName
          ResolveOsvvmFailName(FailNameVar.GetOpt) & "  " &  -- FailName
          Name
        ) ;
        write(buf, "  Total Error(s) = "      & to_string(NumErrors) ) ;
        write(buf, "  Failures: "  & to_string(AlertCount(FAILURE)) ) ;
        write(buf, "  Errors: "    & to_string(AlertCount(ERROR) ) ) ;
        write(buf, "  Warnings: "  & to_string(AlertCount(WARNING) ) ) ;
        write(buf, "  at "  & to_string(NOW, 1 ns)) ;
        writeLine(buf) ;
      end if ;
    end procedure ReportAlerts ;

    ------------------------------------------------------------
    --  pt local
    procedure WriteOneAlertYaml (
    ------------------------------------------------------------
      file TestFile : text ;
      AlertLogID           : AlertLogIDType ;
      TotalErrors          : integer ;
      RequirementsPassed   : integer ;
      RequirementsGoal     : integer ;
      FirstPrefix          : string := "" ;
      Prefix               : string := ""
    ) is
      variable buf : line ;
      constant DELIMITER : string := ", " ;
    begin
      Write(buf,
        FirstPrefix & "Name: " & '"' & AlertLogPtr(AlertLogID).Name.all & '"'  & LF  &
        Prefix & "Status: " & IfElse(TotalErrors=0, "PASSED", "FAILED")        & LF  &
        Prefix & "Results: {" &
          "TotalErrors: "        & to_string( TotalErrors )          & DELIMITER &
          "AlertCount: {" &
            "Failure: "            & to_string( AlertLogPtr(AlertLogID).AlertCount(FAILURE) )  & DELIMITER &
            "Error: "              & to_string( AlertLogPtr(AlertLogID).AlertCount(ERROR) )    & DELIMITER &
            "Warning: "            & to_string( AlertLogPtr(AlertLogID).AlertCount(WARNING) )  &
          "}" & DELIMITER &
          "PassedCount: "        & to_string( AlertLogPtr(AlertLogID).PassedCount )          & DELIMITER &
          "AffirmCount: "        & to_string( AlertLogPtr(AlertLogID).AffirmCount )          & DELIMITER &
          "RequirementsPassed: " & to_string( RequirementsPassed )   & DELIMITER &
          "RequirementsGoal: "   & to_string( RequirementsGoal )     & DELIMITER &
          "DisabledAlertCount: {" &
            "Failure: "            & to_string( AlertLogPtr(AlertLogID).DisabledAlertCount(FAILURE) )  & DELIMITER &
            "Error: "              & to_string( AlertLogPtr(AlertLogID).DisabledAlertCount(ERROR) )    & DELIMITER &
            "Warning: "            & to_string( AlertLogPtr(AlertLogID).DisabledAlertCount(WARNING) )  &
          "}" &
        "}"
      ) ;
      WriteLine(TestFile, buf) ;
    end procedure WriteOneAlertYaml ;

    ------------------------------------------------------------
    -- PT Local
    procedure IterateAndWriteChildrenYaml(
    ------------------------------------------------------------
      file TestFile     : text ;
      AlertLogID        : AlertLogIDType ;
      Prefix            : string
    ) is
      variable buf : line ;
      variable CurID : AlertLogIDType ;
      variable RequirementsPassed, RequirementsGoal : integer ;
    begin
      CurID := AlertLogPtr(AlertLogID).ChildID ;
      if CurID >= ALERTLOG_BASE_ID then
        -- Write "Children:" at current level
        Write(buf, Prefix & "Children: " ) ;
        WriteLine(TestFile, buf) ;
        while CurID > ALERTLOG_BASE_ID loop
          -- Don't print requirements if there no requirements
          if CurID = REQUIREMENT_ALERTLOG_ID and HasRequirementsVar = FALSE then
            CurID := AlertLogPtr(CurID).SiblingID ;
            next ;
          end if ;
          RequirementsGoal   := AlertLogPtr(CurID).PassedGoal ;
          if AlertLogPtr(CurID).PassedGoalSet and (RequirementsGoal > 0) then
            RequirementsPassed := AlertLogPtr(CurID).PassedCount ;
          else
            RequirementsPassed := 0 ;
            RequirementsGoal   := 0 ;
          end if ;
          if AlertLogPtr(AlertLogID).ReportMode /= DISABLED then
            WriteOneAlertYaml(
              TestFile             => TestFile,
              AlertLogID           => CurID,
              TotalErrors          => CalcTotalErrors(CurID),
              RequirementsPassed   => RequirementsPassed,
              RequirementsGoal     => RequirementsGoal,
              FirstPrefix          => Prefix & "  - ",
              Prefix               => Prefix & "    "
            ) ;
            IterateAndWriteChildrenYaml(
              TestFile             => TestFile,
              AlertLogID           => CurID,
              Prefix               => Prefix & "    "
            ) ;
          end if ;
          CurID := AlertLogPtr(CurID).SiblingID ;
        end loop ;
      else
        -- No Children, Print Empty List
        Write(buf, Prefix & "Children: {}" ) ;
        WriteLine(TestFile, buf) ;
      end if ;
    end procedure IterateAndWriteChildrenYaml ;

    ------------------------------------------------------------
    --  pt local
    procedure WriteSettingsYaml (
    ------------------------------------------------------------
      file TestFile  : text ;
      ExternalErrors : AlertCountType ;
      Prefix         : string := ""
    ) is
      variable buf : line ;
      constant DELIMITER : string := ", " ;
    begin
      Write(buf,
        Prefix & "Settings: {" &
          "ExternalErrors: {" &
            "Failure: "                & '"' & to_string( ExternalErrors(FAILURE) )  & '"'  & DELIMITER &
            "Error: "                  & '"' & to_string( ExternalErrors(ERROR) )    & '"'  & DELIMITER &
            "Warning: "                & '"' & to_string( ExternalErrors(WARNING) )  & '"'  &
          "}" & DELIMITER &
          "FailOnDisabledErrors: "     & '"' & to_string( FailOnDisabledErrorsVar )     & '"' & DELIMITER &
          "FailOnRequirementErrors: "  & '"' & to_string( FailOnRequirementErrorsVar )  & '"' & DELIMITER &
          "FailOnWarning: "            & '"' & to_string( FailOnWarningVar )   & '"' &
        "}"
      ) ;
      WriteLine(TestFile, buf) ;
    end procedure WriteSettingsYaml ;


    ------------------------------------------------------------
    --  pt local
    procedure WriteAlertYaml (
    ------------------------------------------------------------
      file TestFile  : text ;
      ExternalErrors : AlertCountType ;
      Prefix         : string ;
      PrintSettings  : boolean ;
      PrintChildren  : boolean
    ) is
      -- Format:  Action Count min1 max1 min2 max2
      variable TotalErrors : integer ;
      variable TotalAlertCount : AlertCountType ;
      variable TotalRequirementsPassed, TotalRequirementsCount : integer ;
    begin
      CalcTopTotalErrors (
        ExternalErrors           => ExternalErrors         ,
        TotalErrors              => TotalErrors            ,
        TotalAlertCount          => TotalAlertCount        ,
        TotalRequirementsPassed  => TotalRequirementsPassed,
        TotalRequirementsCount   => TotalRequirementsCount
      ) ;

      WriteOneAlertYaml (
        TestFile                 => TestFile,
        AlertLogID               => ALERTLOG_BASE_ID,
        TotalErrors              => TotalErrors,
        RequirementsPassed       => TotalRequirementsPassed,
        RequirementsGoal         => TotalRequirementsCount,
        FirstPrefix              => Prefix,
        Prefix                   => Prefix
      ) ;
      if PrintSettings then
        WriteSettingsYaml(
          TestFile               => TestFile,
          ExternalErrors         => ExternalErrors,
          Prefix                 => Prefix
        ) ;
      end if ;
      if PrintChildren then
        IterateAndWriteChildrenYaml(
          TestFile             => TestFile,
          AlertLogID           => ALERTLOG_BASE_ID,
          Prefix               => Prefix
        ) ;
      end if ;
    end procedure WriteAlertYaml ;

    ------------------------------------------------------------
    procedure WriteAlertYaml (
    ------------------------------------------------------------
      FileName       : string ;
      ExternalErrors : AlertCountType := (0,0,0) ;
      Prefix         : string := "" ;
      PrintSettings  : boolean := TRUE ;
      PrintChildren  : boolean := TRUE ;
      OpenKind       : File_Open_Kind := WRITE_MODE
    ) is
      file     FileID : text ;
      variable status : file_open_status ;
    begin
      file_open(status, FileID, FileName, OpenKind) ;
      if status = OPEN_OK then
        WriteAlertYaml(FileID, ExternalErrors, Prefix, PrintSettings, PrintChildren) ;
        file_close(FileID) ;
      else
        Alert("WriteAlertYaml, File: " & FileName & " did not open for " & to_string(OpenKind)) ;
      end if ;
    end procedure WriteAlertYaml ;

    ------------------------------------------------------------
    -- PT Local
    impure function IsRequirement(AlertLogID : AlertLogIDType) return boolean is
    ------------------------------------------------------------
    begin
      if AlertLogID = REQUIREMENT_ALERTLOG_ID then
        return TRUE ;
      elsif AlertLogID <= ALERTLOG_BASE_ID then
        return FALSE ;
      else
        return IsRequirement(AlertLogPtr(AlertLogID).ParentID) ;
      end if ;
    end function IsRequirement ;

    ------------------------------------------------------------
    --  pt local
    procedure WriteOneTestSummary (
    ------------------------------------------------------------
      file TestFile : text ;
      AlertLogID           : AlertLogIDType ;
      RequirementsGoal     : integer ;
      RequirementsPassed   : integer ;
      TotalErrors          : integer ;
      AlertCount           : AlertCountType ;
      AffirmCount          : integer ;
      PassedCount          : integer ;
      Delimiter            : string ;
      Prefix               : string := "" ;
      Suffix               : string := "" ;
      WriteFieldName       : boolean := FALSE
    ) is
      variable buf : line ;
    begin
-- Should disabled errors be included here?
-- In the previous step, we counted DisabledErrors as a regular error if FailOnDisabledErrorsVar (default TRUE)

      Write(buf,
        Prefix &
        IfElse(WriteFieldName, "Status: " & IfElse(TotalErrors=0, "PASSED", "FAILED") & LF, "")  &
        IfElse(WriteFieldName, Prefix & "Results: {Name: ", "") &
        AlertLogPtr(AlertLogID).Name.all  & Delimiter &
        IfElse(WriteFieldName, "RequirementsGoal: ", "") &
        to_string( RequirementsGoal )     & Delimiter &
        IfElse(WriteFieldName, "RequirementsPassed: ", "") &
        to_string( RequirementsPassed )   & Delimiter &
        IfElse(WriteFieldName, "TotalErrors: ", "") &
        to_string( TotalErrors )          & Delimiter &
        IfElse(WriteFieldName, "Failure: ", "") &
        to_string( AlertCount(FAILURE) )  & Delimiter &
        IfElse(WriteFieldName, "Error: ", "") &
        to_string( AlertCount(ERROR) )    & Delimiter &
        IfElse(WriteFieldName, "Warning: ", "") &
        to_string( AlertCount(WARNING) )  & Delimiter &
        IfElse(WriteFieldName, "AffirmCount: ", "") &
        to_string( AffirmCount )          & Delimiter &
        IfElse(WriteFieldName, "PassedCount: ", "") &
        to_string( PassedCount ) &
        IfElse(WriteFieldName, "}", "") &
        Suffix
      ) ;
-- ##      Write(buf,
-- ##        Prefix &
-- ##        IfElse(WriteFieldName, "Status: " & IfElse(TotalErrors=0, "PASSED", "FAILED") & Delimiter, "")  &
-- ##        IfElse(WriteFieldName, "Name: ", "") &
-- ##        AlertLogPtr(AlertLogID).Name.all  & Delimiter &
-- ##        IfElse(WriteFieldName, "RequirementsGoal: ", "") &
-- ##        to_string( RequirementsGoal )     & Delimiter &
-- ##        IfElse(WriteFieldName, "RequirementsPassed: ", "") &
-- ##        to_string( RequirementsPassed )   & Delimiter &
-- ##        IfElse(WriteFieldName, "TotalErrors: ", "") &
-- ##        to_string( TotalErrors )          & Delimiter &
-- ##        IfElse(WriteFieldName, "Failure: ", "") &
-- ##        to_string( AlertCount(FAILURE) )  & Delimiter &
-- ##        IfElse(WriteFieldName, "Error: ", "") &
-- ##        to_string( AlertCount(ERROR) )    & Delimiter &
-- ##        IfElse(WriteFieldName, "Warning: ", "") &
-- ##        to_string( AlertCount(WARNING) )  & Delimiter &
-- ##        IfElse(WriteFieldName, "AffirmCount: ", "") &
-- ##        to_string( AffirmCount )          & Delimiter &
-- ##        IfElse(WriteFieldName, "PassedCount: ", "") &
-- ##        to_string( PassedCount )          & Suffix
-- ##      ) ;


      WriteLine(TestFile, buf) ;
    end procedure WriteOneTestSummary ;

    ------------------------------------------------------------
    --  pt local
    procedure WriteTestSummary (
    ------------------------------------------------------------
      file TestFile  : text ;
      Prefix         : string := "" ;
      Suffix         : string := "" ;
      ExternalErrors : AlertCountType := (0,0,0) ;
      WriteFieldName : boolean := FALSE
    ) is
      -- Format:  Action Count min1 max1 min2 max2
      variable TotalErrors : integer ;
      variable TotalAlertErrors, TotalDisabledAlertErrors : integer ;
      variable TotalRequirementsPassed, TotalRequirementsGoal : integer ;
      variable TotalRequirementErrors : integer ;
      variable TotalAlertCount, DisabledAlertCount : AlertCountType ;
      constant AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID ;
      variable PassedCount, AffirmCount : integer ;
      constant DELIMITER : string := ", " ;
    begin
--!!
--!! Update to use CalcTopTotalErrors
--!!
      TotalAlertCount        := AlertLogPtr(AlertLogID).AlertCount + ExternalErrors ;
      TotalAlertErrors     := SumAlertCount( RemoveNonFailingWarnings(TotalAlertCount)) ;

      DisabledAlertCount        := GetDisabledAlertCount(AlertLogID) ;
      TotalDisabledAlertErrors  := SumAlertCount( RemoveNonFailingWarnings(DisabledAlertCount) ) ;

      GetRequirementsCount(AlertLogID, TotalRequirementsPassed, TotalRequirementsGoal) ;
      TotalRequirementErrors := TotalRequirementsGoal - TotalRequirementsPassed ;

      TotalErrors := TotalAlertErrors ;
      if FailOnDisabledErrorsVar then
        TotalErrors := TotalErrors + TotalDisabledAlertErrors ;
        TotalAlertCount := TotalAlertCount + DisabledAlertCount ;
      end if ;
      if FailOnRequirementErrorsVar then
        TotalErrors := TotalErrors + TotalRequirementErrors ;
      end if ;

      GetPassedAffirmCount(AlertLogID, PassedCount, AffirmCount) ;

      WriteOneTestSummary(
        TestFile             =>  TestFile,
        AlertLogID           =>  AlertLogID,
        RequirementsGoal     =>  TotalRequirementsGoal,
        RequirementsPassed   =>  TotalRequirementsPassed,
        TotalErrors          =>  TotalErrors,
        AlertCount           =>  TotalAlertCount,
        AffirmCount          =>  AffirmCount,
        PassedCount          =>  PassedCount,
        Delimiter            =>  DELIMITER,
        Prefix               =>  Prefix,
        Suffix               =>  Suffix,
        WriteFieldName       => WriteFieldName
      ) ;
    end procedure WriteTestSummary ;

    ------------------------------------------------------------
    procedure WriteTestSummary (
    ------------------------------------------------------------
      FileName       : string ;
      OpenKind       : File_Open_Kind ;
      Prefix         : string ;
      Suffix         : string ;
      ExternalErrors : AlertCountType ;
      WriteFieldName : boolean
    ) is
      -- Format:  Action Count min1 max1 min2 max2
      file TestFile : text open OpenKind is FileName ;
    begin
      WriteTestSummary(TestFile =>  TestFile, Prefix => Prefix, Suffix => Suffix, ExternalErrors => ExternalErrors, WriteFieldName => WriteFieldName) ;
    end procedure WriteTestSummary ;

    ------------------------------------------------------------
    procedure WriteTestSummaries (  -- PT Local
    ------------------------------------------------------------
      file TestFile : text ;
      AlertLogID    : AlertLogIDType
    ) is
     variable CurID : AlertLogIDType ;
     variable TotalErrors, RequirementsGoal, RequirementsPassed : integer ;
    begin
      -- Descend from WriteRequirements
      CurID := AlertLogPtr(AlertLogID).ChildID ;
      while CurID > ALERTLOG_BASE_ID loop
        TotalErrors        := AlertLogPtr(CurID).TotalErrors ;
        RequirementsGoal   := AlertLogPtr(CurID).PassedGoal ;
        RequirementsPassed := AlertLogPtr(CurID).PassedCount ;
        if AlertLogPtr(CurID).AffirmCount <= 0 and FailOnRequirementErrorsVar and
            (RequirementsGoal > RequirementsPassed) then
          -- Add errors for tests that did not run.
          TotalErrors := RequirementsGoal - RequirementsPassed ;
        end if ;
        WriteOneTestSummary(
          TestFile             =>  TestFile,
          AlertLogID           =>  CurID,
          RequirementsGoal     =>  RequirementsGoal,
          RequirementsPassed   =>  RequirementsPassed,
          TotalErrors          =>  TotalErrors,
          AlertCount           =>  AlertLogPtr(CurID).AlertCount,
          AffirmCount          =>  AlertLogPtr(CurID).AffirmCount,
          PassedCount          =>  AlertLogPtr(CurID).AffirmPassedCount,
          Delimiter            =>  ","
        ) ;
        WriteTestSummaries(TestFile, CurID) ;
        CurID := AlertLogPtr(CurID).SiblingID ;
      end loop ;
    end procedure WriteTestSummaries ;

    ------------------------------------------------------------
    procedure WriteTestSummaries (
    ------------------------------------------------------------
      FileName    : string ;
      OpenKind    : File_Open_Kind
    ) is
      -- Format:  Action Count min1 max1 min2 max2
      file TestFile : text open OpenKind is FileName ;
    begin
      WriteTestSummaries(
        TestFile   =>  TestFile,
        AlertLogID => REQUIREMENT_ALERTLOG_ID
      ) ;
    end procedure WriteTestSummaries ;

    ------------------------------------------------------------
    procedure ReportOneTestSummary (  -- PT Local
    ------------------------------------------------------------
      AlertLogID           : AlertLogIDType ;
      RequirementsGoal     : integer ;
      RequirementsPassed   : integer ;
      TotalErrors          : integer ;
      AlertCount           : AlertCountType ;
      AffirmCount          : integer ;
      PassedCount          : integer ;
      Delimiter            : string
    ) is
      variable buf : line ;
      -- constant ReportPrefix    : string := ResolveOsvvmWritePrefix(ReportPrefixVar.GetOpt ) ;
      -- constant PassName        : string := ResolveOsvvmPassName(PassNameVar.GetOpt     ) ;
      -- constant FailName        : string := ResolveOsvvmFailName(FailNameVar.GetOpt     ) ;
    begin
--      write(buf, ReportPrefix &  " ") ;
      write(buf, ResolveOsvvmWritePrefix(ReportPrefixVar.GetOpt) &  " ") ;

      if (AffirmCount > 0) and (TotalErrors = 0) then
--        write(buf, PassName) ;
        write(buf, ResolveOsvvmPassName(PassNameVar.GetOpt)) ;
      elsif TotalErrors > 0 then
--        write(buf, FailName) ;
        write(buf, ResolveOsvvmFailName(FailNameVar.GetOpt)) ;
      else
        write(buf, string'("ReportTestSummaries Warning:  No checking done. ")) ;
      end if ;
      write(buf, " " & LeftJustify(AlertLogPtr(AlertLogID).Name.all, ReportJustifyAmountVar)) ;
      write(buf, "  Total Error(s) = " & to_string(TotalErrors) ) ;
      write(buf, "  Failures: "  & to_string(AlertCount(FAILURE) ) ) ;
      write(buf, "  Errors: "    & to_string(AlertCount(ERROR) ) ) ;
      write(buf, "  Warnings: "  & to_string(AlertCount(WARNING) ) ) ;
      write(buf, "  Affirmations Passed: "  & to_string(PassedCount) &
                 " of " & to_string(AffirmCount)) ;
      write(buf, "  Requirements Passed: " & to_string(RequirementsPassed) &
                 " of " & to_string(RequirementsGoal) ) ;
      WriteLine(buf) ;
    end procedure ReportOneTestSummary ;

    ------------------------------------------------------------
    procedure ReportTestSummaries (  -- PT Local
    ------------------------------------------------------------
      AlertLogID    : AlertLogIDType
    ) is
     variable CurID       : AlertLogIDType ;
     variable TotalErrors, RequirementsGoal, RequirementsPassed : integer ;
    begin
      CurID := AlertLogPtr(AlertLogID).ChildID ;
      while CurID > ALERTLOG_BASE_ID loop
        TotalErrors        := AlertLogPtr(CurID).TotalErrors ;
        RequirementsGoal   := AlertLogPtr(CurID).PassedGoal ;
        RequirementsPassed := AlertLogPtr(CurID).PassedCount ;
        if AlertLogPtr(CurID).AffirmCount <= 0 and FailOnRequirementErrorsVar and
            (RequirementsGoal > RequirementsPassed) then
          -- Add errors for tests that did not run.
          TotalErrors := RequirementsGoal - RequirementsPassed ;
        end if ;
        ReportOneTestSummary(
          AlertLogID           =>  CurID,
          RequirementsGoal     =>  RequirementsGoal,
          RequirementsPassed   =>  RequirementsPassed,
          TotalErrors          =>  TotalErrors,
          AlertCount           =>  AlertLogPtr(CurID).AlertCount,
          AffirmCount          =>  AlertLogPtr(CurID).AffirmCount,
          PassedCount          =>  AlertLogPtr(CurID).AffirmPassedCount,
          Delimiter            =>  ","
        ) ;
        ReportTestSummaries(
          AlertLogID   => CurID
        ) ;
        CurID := AlertLogPtr(CurID).SiblingID ;
      end loop ;
    end procedure ReportTestSummaries ;


    ------------------------------------------------------------
    procedure ReportTestSummaries is
    ------------------------------------------------------------
      variable IgnoredValue, OldReportJustifyAmount : integer ;
      constant Separator : string := ResolveOsvvmIdSeparator(IdSeparatorVar.GetOpt) ;
    begin
      OldReportJustifyAmount  := ReportJustifyAmountVar ;
      (IgnoredValue, ReportJustifyAmountVar) := CalcJustify(REQUIREMENT_ALERTLOG_ID, 0, 0, Separator'length) ;

      ReportTestSummaries(AlertLogID   => REQUIREMENT_ALERTLOG_ID) ;
      ReportJustifyAmountVar := OldReportJustifyAmount ;
    end procedure ReportTestSummaries ;

    ------------------------------------------------------------
    --  pt local
    procedure WriteAlerts (    -- pt local
      file AlertsFile : text ;
      AlertLogID : AlertLogIDType
    ) is
    ------------------------------------------------------------
      -- Format:  Name, PassedGoal, #Passed, #TotalErrors, FAILURE, ERROR, WARNING, Affirmations
      variable buf       : line ;
      variable AlertCountVar   : AlertCountType ;
      constant DELIMITER       : character := ',' ;
      variable CurID : AlertLogIDType ;
    begin
      CurID := AlertLogPtr(AlertLogID).ChildID ;
      while CurID > ALERTLOG_BASE_ID loop
        write(buf, AlertLogPtr(CurID).Name.all) ;
        write(buf, DELIMITER & to_string(AlertLogPtr(CurID).PassedGoal)) ;
        -- Handling for PassedCount > PassedGoal done in ReadRequirements
        write(buf, DELIMITER & to_string(AlertLogPtr(CurID).PassedCount)) ;
        AlertCountVar := AlertLogPtr(CurID).AlertCount ;
        if FailOnDisabledErrorsVar then
          AlertCountVar := AlertCountVar + AlertLogPtr(CurID).DisabledAlertCount ;
        end if;
        -- TotalErrors
        write(buf, DELIMITER & to_string( SumAlertCount(RemoveNonFailingWarnings(AlertCountVar)))) ;
        write(buf, DELIMITER & to_string( AlertCountVar(FAILURE) )) ;
        write(buf, DELIMITER & to_string( AlertCountVar(ERROR) )) ;
        write(buf, DELIMITER & to_string( AlertCountVar(WARNING) )) ;
        write(buf, DELIMITER & to_string( AlertLogPtr(CurID).AffirmCount )) ;
--        write(buf, DELIMITER & to_string(AlertLogPtr(CurID).PassedCount)) ;  -- redundancy intentional, for reading WriteTestSummary
        WriteLine(AlertsFile, buf) ;
        WriteAlerts(AlertsFile, CurID) ;
        CurID := AlertLogPtr(CurID).SiblingID ;
      end loop ;
    end procedure WriteAlerts ;

    ------------------------------------------------------------
    procedure WriteRequirements (
    ------------------------------------------------------------
      FileName    : string ;
      AlertLogID  : AlertLogIDType ;
      OpenKind    : File_Open_Kind
    ) is
      -- Format:  Action Count min1 max1 min2 max2
      file RequirementsFile : text open OpenKind is FileName ;
      variable LocalAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      WriteTestSummary(RequirementsFile) ;
      if IsRequirement(localAlertLogID) then
        WriteAlerts(RequirementsFile, localAlertLogID) ;
      else
        Alert("WriteRequirements: Called without a Requirement") ;
        WriteAlerts(RequirementsFile, REQUIREMENT_ALERTLOG_ID) ;
      end if ;
    end procedure WriteRequirements ;

    ------------------------------------------------------------
    procedure WriteAlerts (
    ------------------------------------------------------------
      FileName    : string ;
      AlertLogID  : AlertLogIDType ;
      OpenKind    : File_Open_Kind
    ) is
      -- Format:  Action Count min1 max1 min2 max2
      file AlertsFile : text open OpenKind is FileName ;
      variable LocalAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      WriteTestSummary(AlertsFile) ;
      WriteAlerts(AlertsFile, localAlertLogID) ;
    end procedure WriteAlerts ;

    ------------------------------------------------------------
    procedure ReadSpecification (file SpecificationFile : text  ; PassedGoalIn : integer ) is  -- PT Local
    ------------------------------------------------------------
      variable buf,Name,Description  : line ;
      variable ReadValid             : boolean ;
      variable Empty                 : boolean ;
      variable MultiLineComment      : boolean := FALSE ;
      variable PassedGoal            : integer ;
      variable PassedGoalSet         : boolean ;
      variable Char                  : character ;
      constant DELIMITER             : character := ',' ;
      variable AlertLogID            : AlertLogIDType ;
    begin
      HasRequirementsVar := TRUE ;

      -- Format:   Spec Name, [Spec Description = "",] [Requirement Goal = 0]
      ReadFileLoop : while not EndFile(SpecificationFile) loop
        ReadLoop : loop
          ReadLine(SpecificationFile, buf) ;
          EmptyOrCommentLine(buf, Empty, MultiLineComment) ;
          next ReadFileLoop when Empty ;

          -- defaults
          PassedGoal    := DefaultPassedGoalVar ;
          PassedGoalSet := FALSE ;

          -- Read Name and Remove delimiter
          ReadUntilDelimiterOrEOL(buf, Name, DELIMITER, ReadValid) ;
          exit ReadFileLoop when AlertIfNot(OSVVM_ALERTLOG_ID, ReadValid,
                         "AlertLogPkg.ReadSpecification: Failed while reading Name", FAILURE) ;

          -- If rest of line is blank or comment, then skip it.
          EmptyOrCommentLine(buf, Empty, MultiLineComment) ;
          exit ReadLoop when Empty ;

          -- Optional: Read Description
          ReadUntilDelimiterOrEOL(buf, Description, DELIMITER, ReadValid) ;
          exit ReadFileLoop when AlertIfNot(OSVVM_ALERTLOG_ID, ReadValid,
                         "AlertLogPkg.ReadSpecification: Failed while reading Description", FAILURE) ;

          if IsNumber(Description.all) then
            read(Description, PassedGoal, ReadValid) ;
            deallocate(Description) ;
            exit ReadFileLoop when AlertIfNot(OSVVM_ALERTLOG_ID, ReadValid,
                           "AlertLogPkg.ReadSpecification: Failed while reading PassedGoal (while skipping Description)", FAILURE) ;
            PassedGoalSet := TRUE ;
          else
            -- If rest of line is blank or comment, then skip it.
            EmptyOrCommentLine(buf, Empty, MultiLineComment) ;
            exit ReadLoop when Empty ;

            -- Read PassedGoal
            read(buf, PassedGoal, ReadValid) ;
            exit ReadFileLoop when AlertIfNot(OSVVM_ALERTLOG_ID, ReadValid,
                           "AlertLogPkg.ReadSpecification: Failed while reading PassedGoal", FAILURE) ;
            PassedGoalSet := TRUE ;
          end if ;
          exit ReadLoop ;
        end loop ReadLoop ;
--        AlertLogID := GetReqID(Name.all) ;  -- For new items, sets DefaultPassedGoalVar and PassedGoalSet = FALSE.
        AlertLogID := GetReqID(Name => Name.all, PassedGoal => -1, ParentID=> ALERTLOG_ID_NOT_ASSIGNED, CreateHierarchy => TRUE) ;
        deallocate(Name) ;
        deallocate(Description) ;  -- not used
        -- Implementation 1:  Just put the values in
        -- If Override values specified, then use them.
        if PassedGoalIn >= 0 then
          PassedGoal    := PassedGoalIn ;
          PassedGoalSet := TRUE ;
        end if ;
        if PassedGoalSet then
        -- Is there a goal to update?
          if AlertLogPtr(AlertLogID).PassedGoalSet then
            -- Merge Old and New
            AlertLogPtr(AlertLogID).PassedGoal    := maximum(PassedGoal,   AlertLogPtr(AlertLogID).PassedGoal) ;
          else
            -- No Old, Just use New
            AlertLogPtr(AlertLogID).PassedGoal    := PassedGoal ;
          end if ;
          AlertLogPtr(AlertLogID).PassedGoalSet := TRUE ;
        end if ;
      end loop ReadFileLoop ;
    end procedure ReadSpecification ;

    ------------------------------------------------------------
    procedure ReadSpecification (FileName : string ; PassedGoal : integer ) is
    ------------------------------------------------------------
      -- Format:  Action Count min1 max1 min2 max2
      file SpecificationFile : text open READ_MODE is FileName ;
    begin
      ReadSpecification(SpecificationFile, PassedGoal) ;
    end procedure ReadSpecification ;

    ------------------------------------------------------------
    -- PT Local
    procedure ReadRequirements (  -- PT Local
      file RequirementsFile : text ;
      ThresholdPassed       : boolean ;
      TestSummary           : boolean
    ) is
    ------------------------------------------------------------
      constant DELIMITER         : character := ',' ;
      variable buf,Name          : line ;
      variable ReadValid         : boolean ;
      variable Empty             : boolean ;
      variable MultiLineComment  : boolean := FALSE ;
      variable StopDueToCount    : boolean := FALSE ;
--      variable ReadFailed        : boolean := TRUE ;
      variable Found             : boolean ;

      variable ReqPassedGoal     : integer ;
      variable ReqPassedCount    : integer ;
      variable TotalErrorCount   : integer ;
      variable AlertCount        : AlertCountType ;
      variable AffirmCount       : integer ;
      variable AffirmPassedCount : integer ;
      variable AlertLogID        : AlertLogIDType ;
    begin
      if not TestSummary then
        -- For requirements, skip the first line that has the test summary
        ReadLine(RequirementsFile, buf) ;
      end if ;

      ReadFileLoop : while not EndFile(RequirementsFile) loop
        ReadLoop : loop
          ReadLine(RequirementsFile, buf) ;
          EmptyOrCommentLine(buf, Empty, MultiLineComment) ;
          next ReadFileLoop when Empty ;

          -- defaults
--          ReadFailed         := TRUE ;
          ReqPassedGoal      := 0 ;
          ReqPassedCount     := 0 ;
          TotalErrorCount    := 0 ;
          AlertCount         := (0, 0, 0) ;
          AffirmCount        := 0 ;
          AffirmPassedCount  := 0 ;

        -- Read Name. Remove delimiter
          ReadUntilDelimiterOrEOL(buf, Name, DELIMITER, ReadValid) ;
          exit ReadFileLoop when AlertIfNot(OSVVM_ALERTLOG_ID, ReadValid,
                         "AlertLogPkg.ReadRequirements: Failed while reading Name", FAILURE) ;

        -- Read ReqPassedGoal
          read(buf, ReqPassedGoal, ReadValid) ;
          exit ReadFileLoop when AlertIfNot(OSVVM_ALERTLOG_ID, ReadValid,
                         "AlertLogPkg.ReadRequirements: Failed while reading PassedGoal", FAILURE) ;

          FindDelimiter(buf, DELIMITER, Found) ;
          exit ReadFileLoop when AlertIf(OSVVM_ALERTLOG_ID, not Found,
                         "AlertLogPkg.ReadRequirements: Failed after reading PassedGoal", FAILURE) ;

        -- Read ReqPassedCount
          read(buf, ReqPassedCount, ReadValid) ;
          exit ReadFileLoop when AlertIfNot(OSVVM_ALERTLOG_ID, ReadValid,
                         "AlertLogPkg.ReadRequirements: Failed while reading PassedCount", FAILURE) ;

          AffirmPassedCount := ReqPassedGoal ;

          FindDelimiter(buf, DELIMITER, Found) ;
            exit ReadFileLoop when AlertIf(OSVVM_ALERTLOG_ID, not Found,
                         "AlertLogPkg.ReadRequirements: Failed after reading PassedCount", FAILURE) ;

        -- Read TotalErrorCount
          read(buf, TotalErrorCount, ReadValid) ;
          exit ReadFileLoop when AlertIfNot(OSVVM_ALERTLOG_ID, ReadValid,
                         "AlertLogPkg.ReadRequirements: Failed while reading TotalErrorCount", FAILURE) ;
          AlertCount := (0, TotalErrorCount, 0) ;  -- Default

          FindDelimiter(buf, DELIMITER, Found) ;
          exit ReadFileLoop when AlertIf(OSVVM_ALERTLOG_ID, not Found,
                         "AlertLogPkg.ReadRequirements: Failed after reading PassedCount", FAILURE) ;

        -- Read AlertCount
          for i in AlertType'left to AlertType'right loop
            read(buf, AlertCount(i), ReadValid) ;
            exit ReadFileLoop when AlertIfNot(OSVVM_ALERTLOG_ID, ReadValid,
                           "AlertLogPkg.ReadRequirements: Failed while reading " &
                           "AlertCount(" & to_string(i) & ")", FAILURE) ;

            FindDelimiter(buf, DELIMITER, Found) ;
            exit ReadFileLoop when AlertIf(OSVVM_ALERTLOG_ID, not Found,
                           "AlertLogPkg.ReadRequirements: Failed after reading " &
                           "AlertCount(" & to_string(i) & ")", FAILURE) ;
          end loop ;

        -- Read AffirmCount
          read(buf, AffirmCount, ReadValid) ;
          exit ReadFileLoop when AlertIfNot(OSVVM_ALERTLOG_ID, ReadValid,
                         "AlertLogPkg.ReadRequirements: Failed while reading AffirmCount", FAILURE) ;

          if TestSummary then
            FindDelimiter(buf, DELIMITER, Found) ;
            exit ReadFileLoop when AlertIf(OSVVM_ALERTLOG_ID, not Found,
                         "AlertLogPkg.ReadRequirements: Failed after reading AffirmCount", FAILURE) ;

          -- Read AffirmPassedCount
            read(buf, AffirmPassedCount, ReadValid) ;
            if not ReadValid then
              AffirmPassedCount := ReqPassedGoal ;
              Alert(OSVVM_ALERTLOG_ID, "AlertLogPkg.ReadRequirements: Failed while reading AffirmPassedCount", FAILURE) ;
              exit ReadFileLoop ;
            end if ;
          end if ;

          exit ReadLoop ;
        end loop ReadLoop ;

--        AlertLogID := GetReqID(Name.all) ;
        AlertLogID := GetReqID(Name => Name.all, PassedGoal => -1, ParentID=> ALERTLOG_ID_NOT_ASSIGNED, CreateHierarchy => TRUE) ;  --! GHDL
        deallocate(Name) ;
--        if Merge then
          -- Passed Goal
          if AlertLogPtr(AlertLogID).PassedGoalSet then
            AlertLogPtr(AlertLogID).PassedGoal        := maximum(AlertLogPtr(AlertLogID).PassedGoal, ReqPassedGoal) ;
          else
            AlertLogPtr(AlertLogID).PassedGoal        := ReqPassedGoal ;
          end if ;
          -- Requirements Passed Count
          if  ThresholdPassed then
            ReqPassedCount := minimum(ReqPassedCount, ReqPassedGoal) ;
          end if ;
          AlertLogPtr(AlertLogID).PassedCount         := AlertLogPtr(AlertLogID).PassedCount + ReqPassedCount ;

          AlertLogPtr(AlertLogID).TotalErrors         := AlertLogPtr(AlertLogID).TotalErrors + TotalErrorCount ;

          -- AlertCount
          IncrementAlertCount(AlertLogID, FAILURE, StopDueToCount, AlertCount(FAILURE)) ;
          IncrementAlertCount(AlertLogID, ERROR,   StopDueToCount, AlertCount(ERROR)) ;
          IncrementAlertCount(AlertLogID, WARNING, StopDueToCount, AlertCount(WARNING)) ;

          -- AffirmCount
          AlertLogPtr(AlertLogID).AffirmCount         := AlertLogPtr(AlertLogID).AffirmCount + AffirmCount ;
          AlertLogPtr(AlertLogID).AffirmPassedCount   := AlertLogPtr(AlertLogID).AffirmPassedCount + AffirmPassedCount ;

--        else
--          AlertLogPtr(AlertLogID).PassedGoal          := ReqPassedGoal ;
--          AlertLogPtr(AlertLogID).PassedCount         := ReqPassedCount ;
--
--          IncrementAlertCount(AlertLogID, FAILURE, StopDueToCount, AlertCount(FAILURE)) ;
--          IncrementAlertCount(AlertLogID, ERROR,   StopDueToCount, AlertCount(ERROR)) ;
--          IncrementAlertCount(AlertLogID, WARNING, StopDueToCount, AlertCount(WARNING)) ;
--
--          AlertLogPtr(AlertLogID).AffirmCount         := ReqPassedCount + TotalErrorCount ;
--        end if;
        AlertLogPtr(AlertLogID).PassedGoalSet := TRUE ;
      end loop ReadFileLoop ;
    end procedure ReadRequirements ;

    ------------------------------------------------------------
    procedure ReadRequirements (
      FileName        : string ;
      ThresholdPassed : boolean ;
      TestSummary     : boolean
    ) is
    ------------------------------------------------------------
      -- Format:  Action Count min1 max1 min2 max2
      file RequirementsFile : text open READ_MODE is FileName ;
    begin
      ReadRequirements(RequirementsFile, ThresholdPassed, TestSummary) ;
    end procedure ReadRequirements ;

    ------------------------------------------------------------
    procedure ClearAlerts is
    ------------------------------------------------------------
    begin
      AffirmCheckCountVar  := 0 ;
      PassedCountVar       := 0 ;
      AlertCount           := (0, 0, 0) ;
      ErrorCount           := 0 ;

      for i in ALERTLOG_BASE_ID to NumAlertLogIDsVar loop
        AlertLogPtr(i).AlertCount           := (0, 0, 0) ;
        AlertLogPtr(i).DisabledAlertCount   := (0, 0, 0) ;
        AlertLogPtr(i).AffirmCount          := 0 ;
        AlertLogPtr(i).PassedCount          := 0 ;
      end loop ;
    end procedure ClearAlerts ;

    ------------------------------------------------------------
    procedure ClearAlertStopCounts is
    ------------------------------------------------------------
    begin
      AlertLogPtr(ALERTLOG_BASE_ID).AlertStopCount := (FAILURE => 0, ERROR => integer'right, WARNING => integer'right) ;

      for i in ALERTLOG_BASE_ID + 1 to NumAlertLogIDsVar loop
        AlertLogPtr(i).AlertStopCount := (FAILURE => integer'right, ERROR => integer'right, WARNING => integer'right) ;
      end loop ;
    end procedure ClearAlertStopCounts ;

    ------------------------------------------------------------
    -- PT Local
    procedure LocalLog (
    ------------------------------------------------------------
      AlertLogID   : AlertLogIDType ;
      Message      : string ;
      Level        : LogType
    ) is
    begin
      LocalPrint(
        AlertLogID       => AlertLogID,
        AlertLogName     => LogPrefixVar.Get(OSVVM_DEFAULT_LOG_PREFIX),  
        WriteErrorCount  => WriteLogErrorCountVar,
        WriteLevel       => WriteLogLevelVar,
        LevelName        => LOG_NAME(Level),
        WriteName        => WriteLogNameVar,
        Message          => Message,
        WriteTime        => WriteLogTimeVar
      ) ;
    end procedure LocalLog ;

    ------------------------------------------------------------
    procedure log (
    ------------------------------------------------------------
      AlertLogID   : AlertLogIDType ;
      Message      : string ;
      Level        : LogType := ALWAYS ;
      Enable       : boolean := FALSE    -- override internal enable
    ) is
      variable localAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      if Level = ALWAYS or Enable then
        LocalLog(localAlertLogID, Message, Level) ;
      elsif AlertLogPtr(localAlertLogID).LogEnabled(Level) then
        LocalLog(localAlertLogID, Message, Level) ;
      end if ;
      if Level = PASSED then
        IncAffirmPassedCount(AlertLogID) ;  -- count the passed and affirmation
      end if ;
    end procedure log ;

    ------------------------------------------------------------
    ------------------------------------------------------------
    -- AlertLog Structure Creation and Interaction Methods

    ------------------------------------------------------------
    procedure SetTestName(Name : string ) is
    ------------------------------------------------------------
    begin
      Deallocate(AlertLogPtr(ALERTLOG_BASE_ID).Name) ;
      AlertLogPtr(ALERTLOG_BASE_ID).Name := new string'(Name) ;
      AlertLogPtr(ALERTLOG_BASE_ID).NameLower  := new string'(to_lower(NAME)) ;
    end procedure SetTestName ;

    ------------------------------------------------------------
    impure function GetAlertLogName(AlertLogID : AlertLogIDType) return string is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      return AlertLogPtr(localAlertLogID).Name.all ;
    end function GetAlertLogName ;

    ------------------------------------------------------------
    -- PT Local
    procedure DeQueueID(AlertLogID : AlertLogIDType) is
    ------------------------------------------------------------
      variable ParentID, CurID : AlertLogIDType ;
    begin
      ParentID := AlertLogPtr(AlertLogID).ParentID ;
      CurID    := AlertLogPtr(ParentID).ChildID ;

      -- Found at top of list
      if AlertLogPtr(ParentID).ChildID = AlertLogID then
        AlertLogPtr(ParentID).ChildID := AlertLogPtr(AlertLogID).SiblingID ;
      else
        -- Find among Siblings
        loop
          if AlertLogPtr(CurID).SiblingID = AlertLogID then
            AlertLogPtr(CurID).SiblingID := AlertLogPtr(AlertLogID).SiblingID ;
            exit ;
          end if ;
          if AlertLogPtr(CurID).SiblingID <= ALERTLOG_BASE_ID then
            Alert("DeQueueID: AlertLogID not found") ;
            exit ;
          end if ;
          CurID := AlertLogPtr(CurID).SiblingID ;
        end loop ;
      end if ;
    end procedure DeQueueID ;

    ------------------------------------------------------------
    -- PT Local
    procedure EnQueueID(AlertLogID, ParentID : AlertLogIDType ; ParentIDSet : boolean := TRUE) is
    ------------------------------------------------------------
      variable CurID : AlertLogIDType ;
    begin
      AlertLogPtr(AlertLogID).ParentIDSet := ParentIDSet ;
      AlertLogPtr(AlertLogID).ParentID    := ParentID ;
      AlertLogPtr(AlertLogID).SiblingID   := ALERTLOG_ID_NOT_ASSIGNED ;

      if AlertLogPtr(ParentID).ChildID < ALERTLOG_BASE_ID then
        AlertLogPtr(ParentID).ChildID     := AlertLogID ;
      else
        CurID := AlertLogPtr(ParentID).ChildIDLast ;
        AlertLogPtr(CurID).SiblingID := AlertLogID ;
      end if ;
      AlertLogPtr(ParentID).ChildIDLast := AlertLogID ;
    end procedure EnQueueID ;

    ------------------------------------------------------------
    -- PT Local
    procedure NewAlertLogRec(AlertLogID : AlertLogIDType ; iName : string ; ParentID : AlertLogIDType; ReportMode : AlertLogReportModeType := ENABLED; PrintParent : AlertLogPrintParentType := PRINT_NAME_AND_PARENT) is
    ------------------------------------------------------------
      variable AlertEnabled   : AlertEnableType ;
      variable AlertStopCount : AlertCountType ;
      variable LogEnabled     : LogEnableType ;
    begin
      AlertLogPtr(AlertLogID) := new AlertLogRecType ;
      if AlertLogID = ALERTLOG_BASE_ID then
        AlertEnabled := (TRUE, TRUE, TRUE) ;
        LogEnabled   := (others => FALSE) ;
        AlertStopCount := (FAILURE => 0, ERROR => integer'right, WARNING => integer'right) ;
        EnQueueID(AlertLogID, ALERTLOG_BASE_ID, TRUE) ;
      else
        if ParentID < ALERTLOG_BASE_ID then
          AlertEnabled := AlertLogPtr(ALERTLOG_BASE_ID).AlertEnabled ;
          LogEnabled   := AlertLogPtr(ALERTLOG_BASE_ID).LogEnabled ;
          EnQueueID(AlertLogID, ALERTLOG_BASE_ID, FALSE) ;
        else
          AlertEnabled := AlertLogPtr(ParentID).AlertEnabled ;
          LogEnabled   := AlertLogPtr(ParentID).LogEnabled ;
          EnQueueID(AlertLogID, ParentID, TRUE) ;
        end if ;
        AlertStopCount := (FAILURE | ERROR | WARNING => integer'right) ;
      end if ;
      AlertLogPtr(AlertLogID).Name                := new string'(iName) ;
      AlertLogPtr(AlertLogID).NameLower           := new string'(to_lower(iName)) ;
      AlertLogPtr(AlertLogID).AlertCount          := (0, 0, 0) ;
      AlertLogPtr(AlertLogID).DisabledAlertCount  := (0, 0, 0) ;
      AlertLogPtr(AlertLogID).AffirmCount         := 0 ;
      AlertLogPtr(AlertLogID).PassedCount         := 0 ;
      AlertLogPtr(AlertLogID).PassedGoal          := 0 ;
      AlertLogPtr(AlertLogID).AlertEnabled        := AlertEnabled ;
      AlertLogPtr(AlertLogID).AlertStopCount      := AlertStopCount ;
      AlertLogPtr(AlertLogID).AlertPrintCount     := (FAILURE | ERROR | WARNING => integer'right) ;
      AlertLogPtr(AlertLogID).LogEnabled          := LogEnabled ;
      AlertLogPtr(AlertLogID).ReportMode          := ReportMode ;
      -- Update PrintParent
      if ParentID > ALERTLOG_BASE_ID then
        AlertLogPtr(AlertLogID).PrintParent := PrintParent ;
      else
        AlertLogPtr(AlertLogID).PrintParent := PRINT_NAME ;
      end if ;

      -- Set ChildID, ChildIDLast, SiblingID to ALERTLOG_ID_NOT_ASSIGNED
      AlertLogPtr(AlertLogID).SiblingID           := ALERTLOG_ID_NOT_ASSIGNED ;
      AlertLogPtr(AlertLogID).ChildID             := ALERTLOG_ID_NOT_ASSIGNED ;
      AlertLogPtr(AlertLogID).ChildIDLast         := ALERTLOG_ID_NOT_ASSIGNED ;
      AlertLogPtr(AlertLogID).TotalErrors         := 0 ;
      AlertLogPtr(AlertLogID).AffirmPassedCount   := 0 ;
    end procedure NewAlertLogRec ;

    ------------------------------------------------------------
    -- PT Local
    -- Construct initial data structure
    procedure LocalInitialize(NewNumAlertLogIDs : AlertLogIDType := MIN_NUM_AL_IDS) is
    ------------------------------------------------------------
    begin
      if NumAllocatedAlertLogIDsVar /= 0 then
        Alert(ALERT_DEFAULT_ID, "AlertLogPkg: Initialize, data structure already initialized", FAILURE) ;
        return ;
      end if ;
      -- Initialize Pointer
      AlertLogPtr := new AlertLogArrayType(ALERTLOG_BASE_ID to ALERTLOG_BASE_ID + NewNumAlertLogIDs) ;
      NumAllocatedAlertLogIDsVar := NewNumAlertLogIDs ;
      -- Create BASE AlertLogID (if it differs from DEFAULT
      NewAlertLogRec(ALERTLOG_BASE_ID, "AlertLogTop", ALERTLOG_BASE_ID) ;
      -- Create DEFAULT AlertLogID
      NewAlertLogRec(ALERT_DEFAULT_ID, "Default", ALERTLOG_BASE_ID) ;
      NumAlertLogIDsVar := ALERT_DEFAULT_ID ;
      -- Create OSVVM AlertLogID (if it differs from DEFAULT
      if OSVVM_ALERTLOG_ID /= ALERT_DEFAULT_ID then
        NewAlertLogRec(OSVVM_ALERTLOG_ID, "OSVVM", ALERTLOG_BASE_ID) ;
        NumAlertLogIDsVar := NumAlertLogIDsVar + 1 ;
      end if ;
      if REQUIREMENT_ALERTLOG_ID /= ALERT_DEFAULT_ID then
        NewAlertLogRec(REQUIREMENT_ALERTLOG_ID, "Requirements", ALERTLOG_BASE_ID) ;
        NumAlertLogIDsVar := NumAlertLogIDsVar + 1 ;
      end if ;
      if OSVVM_SCOREBOARD_ALERTLOG_ID /= OSVVM_ALERTLOG_ID then
        NewAlertLogRec(OSVVM_SCOREBOARD_ALERTLOG_ID, "OSVVM Scoreboard", ALERTLOG_BASE_ID) ;
        NumAlertLogIDsVar := NumAlertLogIDsVar + 1 ;
      end if ;
    end procedure LocalInitialize ;

    ------------------------------------------------------------
    -- Construct initial data structure
    procedure Initialize(NewNumAlertLogIDs : AlertLogIDType := MIN_NUM_AL_IDS) is
    ------------------------------------------------------------
    begin
      LocalInitialize(NewNumAlertLogIDs) ;
    end procedure Initialize ;

    ------------------------------------------------------------
    -- PT Local
    -- Constructs initial data structure using constant below
    impure function LocalInitialize return boolean is
    ------------------------------------------------------------
    begin
      LocalInitialize(MIN_NUM_AL_IDS) ;
      return TRUE ;
    end function LocalInitialize ;

    constant CONSTRUCT_ALERT_DATA_STRUCTURE : boolean := LocalInitialize ;

    ------------------------------------------------------------
    procedure DeallocateAlertLogStruct is
    ------------------------------------------------------------
    begin
      for i in ALERTLOG_BASE_ID to NumAlertLogIDsVar loop
        Deallocate(AlertLogPtr(i).Name) ;
        Deallocate(AlertLogPtr(i)) ;
      end loop ;
      deallocate(AlertLogPtr) ;
      -- Free up space used by protected types within AlertLogPkg
      AlertPrefixVar.Deallocate ;
      LogPrefixVar.Deallocate ;
      ReportPrefixVar.Deallocate ;
      DoneNameVar.Deallocate ;
      PassNameVar.Deallocate ;
      FailNameVar.Deallocate ;
      -- Restore variables to their initial state
      PrintPassedVar              := TRUE ;
      PrintAffirmationsVar        := FALSE ;
      PrintDisabledAlertsVar      := FALSE ;
      PrintRequirementsVar        := FALSE ;
      PrintIfHaveRequirementsVar  := TRUE ;
      DefaultPassedGoalVar        := 1 ;
      NumAlertLogIDsVar           := 0 ;
      NumAllocatedAlertLogIDsVar  := 0 ;
      GlobalAlertEnabledVar       := TRUE ; -- Allows turn off and on
      AffirmCheckCountVar         := 0 ;
      PassedCountVar              := 0 ;
      FailOnWarningVar            := TRUE ;
      FailOnDisabledErrorsVar     := TRUE ;
      FailOnRequirementErrorsVar  := TRUE ;
      ReportHierarchyVar          := TRUE ;
      FoundReportHierVar          := FALSE ;
      FoundAlertHierVar           := FALSE ;
      WriteAlertErrorCountVar     := FALSE ;
      WriteAlertLevelVar          := TRUE ;
      WriteAlertNameVar           := TRUE ;
      WriteAlertTimeVar           := TRUE ;
      WriteLogErrorCountVar       := FALSE ;
      WriteLogLevelVar            := TRUE ;
      WriteLogNameVar             := TRUE ;
      WriteLogTimeVar             := TRUE ;
      WriteTimeLastVar            := TRUE ;
      AlertLogJustifyAmountVar    := 0 ;
      ReportJustifyAmountVar      := 0 ;
      TimeJustifyAmountVar        := 0 ;
    end procedure DeallocateAlertLogStruct ;

    ------------------------------------------------------------
    -- PT Local.
    procedure GrowAlertStructure (NewNumAlertLogIDs : AlertLogIDType) is
    ------------------------------------------------------------
      variable oldAlertLogPtr : AlertLogArrayPtrType ;
    begin
      if NumAllocatedAlertLogIDsVar = 0 then
        Initialize (NewNumAlertLogIDs) ;   -- Construct initial structure
      else
        oldAlertLogPtr := AlertLogPtr ;
        AlertLogPtr := new AlertLogArrayType(ALERTLOG_BASE_ID to NewNumAlertLogIDs) ;
        AlertLogPtr(ALERTLOG_BASE_ID to NumAlertLogIDsVar) := oldAlertLogPtr(ALERTLOG_BASE_ID to NumAlertLogIDsVar) ;
        deallocate(oldAlertLogPtr) ;
      end if ;
      NumAllocatedAlertLogIDsVar := NewNumAlertLogIDs ;
    end procedure GrowAlertStructure ;

    ------------------------------------------------------------
    -- Sets a AlertLogPtr to a particular size
    -- Use for small bins to save space or large bins to
    -- suppress the resize and copy in autosizes.
    procedure SetNumAlertLogIDs (NewNumAlertLogIDs : AlertLogIDType) is
    ------------------------------------------------------------
      variable oldAlertLogPtr : AlertLogArrayPtrType ;
    begin
      if NewNumAlertLogIDs > NumAllocatedAlertLogIDsVar then
        GrowAlertStructure(NewNumAlertLogIDs) ;
      end if;
    end procedure SetNumAlertLogIDs ;

    ------------------------------------------------------------
    -- PT Local
    impure function GetNextAlertLogID return AlertLogIDType is
    ------------------------------------------------------------
      variable NewNumAlertLogIDs : AlertLogIDType ;
    begin
      NewNumAlertLogIDs := NumAlertLogIDsVar + 1 ;
      if NewNumAlertLogIDs > NumAllocatedAlertLogIDsVar then
        GrowAlertStructure(NumAllocatedAlertLogIDsVar + MIN_NUM_AL_IDS) ;
      end if ;
      NumAlertLogIDsVar := NewNumAlertLogIDs ;
      return NumAlertLogIDsVar ;
    end function GetNextAlertLogID ;

    ------------------------------------------------------------
    impure function FindAlertLogID(Name : string ) return AlertLogIDType is
    ------------------------------------------------------------
      constant NameLower : string := to_lower(Name) ;
    begin
      for i in ALERTLOG_BASE_ID+1 to NumAlertLogIDsVar loop
        if NameLower = AlertLogPtr(i).NameLower.all then
          return i ;
        end if ;
      end loop ;
      return ALERTLOG_ID_NOT_FOUND ; -- not found
    end function FindAlertLogID ;

    ------------------------------------------------------------
    -- PT Local
    impure function LocalFindAlertLogID(Name : string ; ParentID : AlertLogIDType) return AlertLogIDType is
    ------------------------------------------------------------
      constant NameLower : string := to_lower(Name) ;
    begin
      if ParentID = ALERTLOG_ID_NOT_ASSIGNED then
        return FindAlertLogID(Name) ;
      else
        for i in ALERTLOG_BASE_ID+1 to NumAlertLogIDsVar loop
          if NameLower = AlertLogPtr(i).NameLower.all and
            (AlertLogPtr(i).ParentID = ParentID or AlertLogPtr(i).ParentIDSet = FALSE)
          then
            return i ;
          end if ;
        end loop ;
        return ALERTLOG_ID_NOT_FOUND ; -- not found
      end if ;
    end function LocalFindAlertLogID ;

    ------------------------------------------------------------
    impure function FindAlertLogID(Name : string ; ParentID : AlertLogIDType) return AlertLogIDType is
    ------------------------------------------------------------
      variable localParentID : AlertLogIDType ;
    begin
      localParentID := VerifyID(ParentID, ALERTLOG_ID_NOT_ASSIGNED) ;
      return LocalFindAlertLogID(Name, localParentID) ;
    end function FindAlertLogID ;

    ------------------------------------------------------------
    -- PT Local
    procedure AdjustID(AlertLogID, ParentID : AlertLogIDType ; ParentIDSet : boolean := TRUE) is
    ------------------------------------------------------------
    begin
      if IsRequirement(AlertLogID) and not IsRequirement(ParentID) then
        Alert(AlertLogID, "GetAlertLogID/GetReqID: Parent of a Requirement must be a Requirement") ;
      else
        if ParentID /= AlertLogPtr(AlertLogID).ParentID then
          DeQueueID(AlertLogID) ;
          EnQueueID(AlertLogID, ParentID, ParentIDSet) ;
        else
          AlertLogPtr(AlertLogID).ParentIDSet := ParentIDSet ;
        end if ;
      end if ;
    end procedure AdjustID ;

    ------------------------------------------------------------
    impure function NewID(
      Name            : string ;
      ParentID        : AlertLogIDType ;
      ReportMode      : AlertLogReportModeType ;
      PrintParent     : AlertLogPrintParentType ;
      CreateHierarchy : boolean
    ) return AlertLogIDType is
    -- impure function GetAlertLogID(Name : string; ParentID : AlertLogIDType; CreateHierarchy : Boolean; DoNotReport : Boolean) return AlertLogIDType is
    ------------------------------------------------------------
      variable ResultID : AlertLogIDType ;
      variable localParentID : AlertLogIDType ;
    begin
      localParentID := VerifyID(ParentID, ALERTLOG_ID_NOT_ASSIGNED, ALERTLOG_ID_NOT_ASSIGNED) ;
      ResultID      := LocalFindAlertLogID(Name, localParentID) ;
      if ResultID = ALERTLOG_ID_NOT_FOUND then
        -- Create a new ID
        ResultID := GetNextAlertLogID ;
        NewAlertLogRec(ResultID, Name, localParentID, ReportMode, PrintParent) ;
        FoundAlertHierVar := TRUE ;
        if CreateHierarchy and ReportMode /= DISABLED then
          FoundReportHierVar := TRUE ;
        end if ;
        AlertLogPtr(ResultID).PassedGoal := 0 ;
        AlertLogPtr(ResultID).PassedGoalSet := FALSE ;
      else
        -- Found existing ID.  Update it.
        if AlertLogPtr(ResultID).ParentIDSet = FALSE then
          if localParentID /= ALERTLOG_ID_NOT_ASSIGNED then
            -- Update ParentID and potentially relocate in the structure
            AdjustID(ResultID, localParentID, TRUE) ;
            -- Update PrintParent
            if localParentID /= ALERTLOG_BASE_ID then
              AlertLogPtr(ResultID).PrintParent := PrintParent ;
            else
              AlertLogPtr(ResultID).PrintParent := PRINT_NAME ;
            end if ;
          -- else -- do not update as ParentIDs are either same or input localParentID = ALERTLOG_ID_NOT_ASSIGNED
          end if ;
        end if ;
      end if ;
      return ResultID ;
    end function NewID ;

    ------------------------------------------------------------
    impure function GetReqID(Name : string ; PassedGoal : integer ; ParentID : AlertLogIDType ; CreateHierarchy : Boolean) return AlertLogIDType is
    ------------------------------------------------------------
      variable ResultID : AlertLogIDType ;
      variable localParentID : AlertLogIDType ;
    begin
      HasRequirementsVar := TRUE ;
      localParentID := VerifyID(ParentID, ALERTLOG_ID_NOT_ASSIGNED, ALERTLOG_ID_NOT_ASSIGNED) ;
      ResultID := LocalFindAlertLogID(Name, localParentID) ;
      if ResultID = ALERTLOG_ID_NOT_FOUND then
        -- Create a new ID
        ResultID := GetNextAlertLogID ;
        if localParentID = ALERTLOG_ID_NOT_ASSIGNED then
          NewAlertLogRec(ResultID, Name, REQUIREMENT_ALERTLOG_ID, ENABLED, PRINT_NAME) ;
          AlertLogPtr(ResultID).ParentIDSet := FALSE ;
        else
          -- May want just PRINT_NAME here as PRINT_NAME_AND_PARENT is not backward compatible
--          NewAlertLogRec(ResultID, Name, localParentID, ENABLED, PRINT_NAME_AND_PARENT) ;
          NewAlertLogRec(ResultID, Name, localParentID, ENABLED, PRINT_NAME) ;
        end if ;
        FoundAlertHierVar := TRUE ;
        if CreateHierarchy then
          FoundReportHierVar := TRUE ;
        end if ;
        if PassedGoal >= 0 then
          AlertLogPtr(ResultID).PassedGoal := PassedGoal ;
          AlertLogPtr(ResultID).PassedGoalSet := TRUE ;
        else
          AlertLogPtr(ResultID).PassedGoal := DefaultPassedGoalVar ;
          AlertLogPtr(ResultID).PassedGoalSet := FALSE ;
        end if ;
      else
        -- Found existing ID.  Update it.
        if AlertLogPtr(ResultID).ParentIDSet = FALSE then
          if localParentID /= ALERTLOG_ID_NOT_ASSIGNED then
            AdjustID(ResultID, localParentID, TRUE) ;
            if localParentID /= REQUIREMENT_ALERTLOG_ID then
              -- May want just PRINT_NAME here as PRINT_NAME_AND_PARENT is not backward compatible
--              AlertLogPtr(ResultID).PrintParent := PRINT_NAME_AND_PARENT ;
              AlertLogPtr(ResultID).PrintParent := PRINT_NAME ;
            else
              AlertLogPtr(ResultID).PrintParent := PRINT_NAME ;
            end if ;
          else
            -- Update if originally set by NewID/GetAlertLogID
            AdjustID(ResultID, REQUIREMENT_ALERTLOG_ID, FALSE) ;
          end if ;
        end if ;
        if AlertLogPtr(ResultID).PassedGoalSet = FALSE then
          if PassedGoal >= 0 then
            AlertLogPtr(ResultID).PassedGoal    := PassedGoal ;
            AlertLogPtr(ResultID).PassedGoalSet := TRUE ;
          else
            AlertLogPtr(ResultID).PassedGoal    := DefaultPassedGoalVar ;
            AlertLogPtr(ResultID).PassedGoalSet := FALSE ;
          end if ;
        end if ;
      end if ;
      return ResultID ;
    end function GetReqID ;

    ------------------------------------------------------------
    procedure SetPassedGoal(AlertLogID : AlertLogIDType ; PassedGoal : integer ) is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      HasRequirementsVar := TRUE ;
      localAlertLogID := VerifyID(AlertLogID) ;
      if PassedGoal >= 0 then
        AlertLogPtr(localAlertLogID).PassedGoal := PassedGoal ;
      else
        AlertLogPtr(localAlertLogID).PassedGoal := DefaultPassedGoalVar ;
      end if ;
    end procedure SetPassedGoal ;

    ------------------------------------------------------------
    impure function GetAlertLogParentID(AlertLogID : AlertLogIDType) return AlertLogIDType is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      return AlertLogPtr(localAlertLogID).ParentID ;
    end function GetAlertLogParentID ;

    ------------------------------------------------------------
    procedure SetAlertLogPrefix(AlertLogID : AlertLogIDType; Name : string ) is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      Deallocate(AlertLogPtr(localAlertLogID).Prefix) ;
      if Name'length > 0 then
        AlertLogPtr(localAlertLogID).Prefix := new string'(Name) ;
      end if ;
    end procedure SetAlertLogPrefix ;

    ------------------------------------------------------------
    procedure UnSetAlertLogPrefix(AlertLogID : AlertLogIDType) is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      Deallocate(AlertLogPtr(localAlertLogID).Prefix) ;
    end procedure UnSetAlertLogPrefix ;

    ------------------------------------------------------------
    impure function GetAlertLogPrefix(AlertLogID : AlertLogIDType) return string is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      return AlertLogPtr(localAlertLogID).Prefix.all ;
    end function GetAlertLogPrefix ;

    ------------------------------------------------------------
    procedure SetAlertLogSuffix(AlertLogID : AlertLogIDType; Name : string ) is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      Deallocate(AlertLogPtr(localAlertLogID).Suffix) ;
      if Name'length > 0 then
        AlertLogPtr(localAlertLogID).Suffix := new string'(Name) ;
      end if ;
    end procedure SetAlertLogSuffix ;

    ------------------------------------------------------------
    procedure UnSetAlertLogSuffix(AlertLogID : AlertLogIDType) is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      Deallocate(AlertLogPtr(localAlertLogID).Suffix) ;
    end procedure UnSetAlertLogSuffix ;

    ------------------------------------------------------------
    impure function GetAlertLogSuffix(AlertLogID : AlertLogIDType) return string is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      return AlertLogPtr(localAlertLogID).Suffix.all ;
    end function GetAlertLogSuffix ;

    ------------------------------------------------------------
    ------------------------------------------------------------
    -- Accessor Methods
    ------------------------------------------------------------

    ------------------------------------------------------------
    procedure SetGlobalAlertEnable (A : boolean := TRUE) is
    ------------------------------------------------------------
    begin
      GlobalAlertEnabledVar := A ;
    end procedure SetGlobalAlertEnable ;

    ------------------------------------------------------------
    impure function GetGlobalAlertEnable return boolean is
    ------------------------------------------------------------
    begin
      return GlobalAlertEnabledVar ;
    end function GetGlobalAlertEnable ;

    ------------------------------------------------------------
    -- PT LOCAL
    procedure SetOneStopCount(
    ------------------------------------------------------------
      AlertLogID   : AlertLogIDType ;
      Level        : AlertType ;
      Count        : integer
    ) is
    begin
      if AlertLogPtr(AlertLogID).AlertStopCount(Level) = integer'right then
        AlertLogPtr(AlertLogID).AlertStopCount(Level) := Count ;
      else
        AlertLogPtr(AlertLogID).AlertStopCount(Level) :=
          AlertLogPtr(AlertLogID).AlertStopCount(Level) + Count ;
      end if ;
    end procedure SetOneStopCount ;

    ------------------------------------------------------------
    -- PT Local
    procedure LocalSetAlertStopCount(AlertLogID : AlertLogIDType ;  Level : AlertType ;  Count : integer) is
    ------------------------------------------------------------
    begin
      SetOneStopCount(AlertLogID, Level, Count) ;
      if AlertLogID /= ALERTLOG_BASE_ID then
        LocalSetAlertStopCount(AlertLogPtr(AlertLogID).ParentID, Level, Count) ;
      end if ;
    end procedure LocalSetAlertStopCount ;

    ------------------------------------------------------------
    procedure SetAlertStopCount(AlertLogID : AlertLogIDType ;  Level : AlertType ;  Count : integer) is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      LocalSetAlertStopCount(localAlertLogID, Level, Count) ;
    end procedure SetAlertStopCount ;

    ------------------------------------------------------------
    impure function GetAlertStopCount(AlertLogID : AlertLogIDType ;  Level : AlertType) return integer is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      return AlertLogPtr(localAlertLogID).AlertStopCount(Level) ;
    end function GetAlertStopCount ;

    ------------------------------------------------------------
    procedure SetAlertPrintCount(AlertLogID : AlertLogIDType ;  Level : AlertType ;  Count : integer) is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      AlertLogPtr(localAlertLogID).AlertPrintCount(Level) := Count ;
    end procedure SetAlertPrintCount ;

    ------------------------------------------------------------
    impure function GetAlertPrintCount(AlertLogID : AlertLogIDType ;  Level : AlertType) return integer is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      return AlertLogPtr(localAlertLogID).AlertPrintCount(Level) ;
    end function GetAlertPrintCount ;

    ------------------------------------------------------------
    procedure SetAlertPrintCount(AlertLogID : AlertLogIDType ;  Count : AlertCountType) is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      AlertLogPtr(localAlertLogID).AlertPrintCount(FAILURE) := Count(FAILURE) ;
      AlertLogPtr(localAlertLogID).AlertPrintCount(ERROR)   := Count(ERROR) ;
      AlertLogPtr(localAlertLogID).AlertPrintCount(WARNING) := Count(WARNING) ;
    end procedure SetAlertPrintCount ;

    ------------------------------------------------------------
    impure function GetAlertPrintCount(AlertLogID : AlertLogIDType) return AlertCountType is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      return AlertLogPtr(localAlertLogID).AlertPrintCount ;
    end function GetAlertPrintCount ;

    ------------------------------------------------------------
    procedure SetAlertLogPrintParent(AlertLogID : AlertLogIDType ;  PrintParent : AlertLogPrintParentType) is
    ------------------------------------------------------------
      variable localAlertLogID, ParentID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      ParentID := AlertLogPtr(localAlertLogID).ParentID ;
      if (ParentID = ALERTLOG_BASE_ID or ParentID = REQUIREMENT_ALERTLOG_ID) then
        AlertLogPtr(localAlertLogID).PrintParent := PRINT_NAME ;
      else
        AlertLogPtr(localAlertLogID).PrintParent := PrintParent ;
      end if ;
    end procedure SetAlertLogPrintParent ;

    ------------------------------------------------------------
    impure function GetAlertLogPrintParent(AlertLogID : AlertLogIDType) return AlertLogPrintParentType is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      return AlertLogPtr(localAlertLogID).PrintParent ;
    end function GetAlertLogPrintParent ;

    ------------------------------------------------------------
    procedure SetAlertLogReportMode(AlertLogID : AlertLogIDType ;  ReportMode : AlertLogReportModeType) is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      AlertLogPtr(localAlertLogID).ReportMode := ReportMode ;
    end procedure SetAlertLogReportMode ;

    ------------------------------------------------------------
    impure function GetAlertLogReportMode(AlertLogID : AlertLogIDType) return AlertLogReportModeType is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      return AlertLogPtr(localAlertLogID).ReportMode ;
    end function GetAlertLogReportMode ;

    ------------------------------------------------------------
    procedure SetAlertEnable(Level : AlertType ;  Enable : boolean) is
    ------------------------------------------------------------
    begin
      for i in ALERTLOG_BASE_ID to NumAlertLogIDsVar loop
        AlertLogPtr(i).AlertEnabled(Level) := Enable ;
      end loop ;
    end procedure SetAlertEnable ;

    ------------------------------------------------------------
    -- PT Local
    procedure LocalSetAlertEnable(AlertLogID : AlertLogIDType ;  Level : AlertType ;  Enable : boolean ; DescendHierarchy : boolean := TRUE) is
    ------------------------------------------------------------
      variable CurID : AlertLogIDType ;
    begin
      AlertLogPtr(AlertLogID).AlertEnabled(Level) := Enable ;
      if DescendHierarchy then
        CurID := AlertLogPtr(AlertLogID).ChildID ;
        while CurID > ALERTLOG_BASE_ID loop
          LocalSetAlertEnable(CurID, Level, Enable, DescendHierarchy) ;
          CurID := AlertLogPtr(CurID).SiblingID ;
        end loop ;
      end if ;
    end procedure LocalSetAlertEnable ;

    ------------------------------------------------------------
    procedure SetAlertEnable(AlertLogID : AlertLogIDType ;  Level : AlertType ;  Enable : boolean ; DescendHierarchy : boolean := TRUE) is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      LocalSetAlertEnable(localAlertLogID, Level, Enable, DescendHierarchy) ;
    end procedure SetAlertEnable ;

    ------------------------------------------------------------
    impure function GetAlertEnable(AlertLogID : AlertLogIDType ;  Level : AlertType) return boolean is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      return AlertLogPtr(localAlertLogID).AlertEnabled(Level) ;
    end function GetAlertEnable ;

    ------------------------------------------------------------
    procedure SetLogEnable(Level : LogType ;  Enable : boolean) is
    ------------------------------------------------------------
    begin
      for i in ALERTLOG_BASE_ID to NumAlertLogIDsVar loop
        AlertLogPtr(i).LogEnabled(Level) := Enable ;
      end loop ;
    end procedure SetLogEnable ;

    ------------------------------------------------------------
    -- PT Local
    procedure LocalSetLogEnable(AlertLogID : AlertLogIDType ;  Level : LogType ;  Enable : boolean ; DescendHierarchy : boolean := TRUE) is
    ------------------------------------------------------------
      variable CurID : AlertLogIDType ;
    begin
      AlertLogPtr(AlertLogID).LogEnabled(Level) := Enable ;
      if DescendHierarchy then
        CurID := AlertLogPtr(AlertLogID).ChildID ;
        while CurID > ALERTLOG_BASE_ID loop
          LocalSetLogEnable(CurID, Level, Enable, DescendHierarchy) ;
          CurID := AlertLogPtr(CurID).SiblingID ;
        end loop ;
      end if ;
    end procedure LocalSetLogEnable ;

    ------------------------------------------------------------
    procedure SetLogEnable(AlertLogID : AlertLogIDType ;  Level : LogType ;  Enable : boolean ; DescendHierarchy : boolean := TRUE) is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      LocalSetLogEnable(localAlertLogID, Level, Enable, DescendHierarchy) ;
    end procedure SetLogEnable ;

    ------------------------------------------------------------
    impure function GetLogEnable(AlertLogID : AlertLogIDType ;  Level : LogType) return boolean is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      if Level = ALWAYS then
        return TRUE ;
      else
        return AlertLogPtr(localAlertLogID).LogEnabled(Level) ;
      end if ;
    end function GetLogEnable ;

    ------------------------------------------------------------
    -- PT Local
    procedure PrintLogLevels(
    ------------------------------------------------------------
      AlertLogID   : AlertLogIDType ;
      Prefix       : string ;
      IndentAmount : integer
    ) is
      variable buf : line ;
      variable CurID : AlertLogIDType ;
    begin
      write(buf, Prefix &  " "   & LeftJustify(AlertLogPtr(AlertLogID).Name.all, ReportJustifyAmountVar - IndentAmount)) ;
      for i in LogIndexType loop
        if AlertLogPtr(AlertLogID).LogEnabled(i) then
--          write(buf, " "  & to_string(AlertLogPtr(AlertLogID).LogEnabled(i)) ) ;
          write(buf, " "  & to_string(i)) ;
        end if ;
      end loop ;
      WriteLine(buf) ;
      CurID := AlertLogPtr(AlertLogID).ChildID ;
      while CurID > ALERTLOG_BASE_ID loop
-- Always print requirements
--        if CurID = REQUIREMENT_ALERTLOG_ID and HasRequirementsVar = FALSE then
--          CurID := AlertLogPtr(CurID).SiblingID ;
--          next ;
--        end if ;
        PrintLogLevels(
          AlertLogID    => CurID,
          Prefix        => Prefix & "  ",
          IndentAmount  => IndentAmount + 2
        ) ;
        CurID := AlertLogPtr(CurID).SiblingID ;
      end loop ;
    end procedure PrintLogLevels ;

    ------------------------------------------------------------
    procedure ReportLogEnables is
    ------------------------------------------------------------
      variable TurnedOnJustify : boolean := FALSE ;
    begin
      if ReportJustifyAmountVar <= 0 then
        TurnedOnJustify := TRUE ;
        SetJustify ;
      end if ;
      PrintLogLevels(ALERTLOG_BASE_ID, "", 0) ;
      if TurnedOnJustify then
        -- Turn it back off
        SetJustify(FALSE) ;
      end if ;
    end procedure ReportLogEnables ;

    ------------------------------------------------------------
    procedure SetAlertLogOptions (
    ------------------------------------------------------------
      FailOnWarning            : OsvvmOptionsType ;
      FailOnDisabledErrors     : OsvvmOptionsType ;
      FailOnRequirementErrors  : OsvvmOptionsType ;
      ReportHierarchy          : OsvvmOptionsType ;
      WriteAlertErrorCount     : OsvvmOptionsType ;
      WriteAlertLevel          : OsvvmOptionsType ;
      WriteAlertName           : OsvvmOptionsType ;
      WriteAlertTime           : OsvvmOptionsType ;
      WriteLogErrorCount       : OsvvmOptionsType ;
      WriteLogLevel            : OsvvmOptionsType ;
      WriteLogName             : OsvvmOptionsType ;
      WriteLogTime             : OsvvmOptionsType ;
      PrintPassed              : OsvvmOptionsType ;
      PrintAffirmations        : OsvvmOptionsType ;
      PrintDisabledAlerts      : OsvvmOptionsType ;
      PrintRequirements        : OsvvmOptionsType ;
      PrintIfHaveRequirements  : OsvvmOptionsType ;
      DefaultPassedGoal        : integer ;
      AlertPrefix              : string ;
      LogPrefix                : string ;
      ReportPrefix             : string ;
      DoneName                 : string ;
      PassName                 : string ;
      FailName                 : string ;
      IdSeparator              : string ;
      WriteTimeLast            : OsvvmOptionsType ;
      TimeJustifyAmount        : integer 
    ) is
    begin
      if FailOnWarning /= OPT_INIT_PARM_DETECT then
        FailOnWarningVar := IsEnabled(FailOnWarning) ;
      end if ;
      if FailOnDisabledErrors /= OPT_INIT_PARM_DETECT then
        FailOnDisabledErrorsVar := IsEnabled(FailOnDisabledErrors) ;
      end if ;
      if FailOnRequirementErrors /= OPT_INIT_PARM_DETECT then
        FailOnRequirementErrorsVar := IsEnabled(FailOnRequirementErrors) ;
      end if ;
      if ReportHierarchy /= OPT_INIT_PARM_DETECT then
        ReportHierarchyVar := IsEnabled(ReportHierarchy) ;
      end if ;
      if WriteAlertErrorCount /= OPT_INIT_PARM_DETECT then
        WriteAlertErrorCountVar := IsEnabled(WriteAlertErrorCount) ;
      end if ;
      if WriteAlertLevel /= OPT_INIT_PARM_DETECT then
        WriteAlertLevelVar := IsEnabled(WriteAlertLevel) ;
      end if ;
      if WriteAlertName /= OPT_INIT_PARM_DETECT then
        WriteAlertNameVar := IsEnabled(WriteAlertName) ;
      end if ;
      if WriteAlertTime /= OPT_INIT_PARM_DETECT then
        WriteAlertTimeVar := IsEnabled(WriteAlertTime) ;
      end if ;
      if WriteLogErrorCount /= OPT_INIT_PARM_DETECT then
        WriteLogErrorCountVar := IsEnabled(WriteLogErrorCount) ;
      end if ;
      if WriteLogLevel /= OPT_INIT_PARM_DETECT then
        WriteLogLevelVar := IsEnabled(WriteLogLevel) ;
      end if ;
      if WriteLogName /= OPT_INIT_PARM_DETECT then
        WriteLogNameVar := IsEnabled(WriteLogName) ;
      end if ;
      if WriteLogTime /= OPT_INIT_PARM_DETECT then
        WriteLogTimeVar := IsEnabled(WriteLogTime) ;
      end if ;
      if PrintPassed /= OPT_INIT_PARM_DETECT then
        PrintPassedVar := IsEnabled(PrintPassed) ;
      end if ;
      if PrintAffirmations /= OPT_INIT_PARM_DETECT then
        PrintAffirmationsVar := IsEnabled(PrintAffirmations) ;
      end if ;
      if PrintDisabledAlerts /= OPT_INIT_PARM_DETECT then
        PrintDisabledAlertsVar := IsEnabled(PrintDisabledAlerts) ;
      end if ;
      if PrintRequirements /= OPT_INIT_PARM_DETECT then
        PrintRequirementsVar := IsEnabled(PrintRequirements) ;
      end if ;
      if PrintIfHaveRequirements /= OPT_INIT_PARM_DETECT then
        PrintIfHaveRequirementsVar := IsEnabled(PrintIfHaveRequirements) ;
      end if ;
      if DefaultPassedGoal > 0 then
        DefaultPassedGoalVar := DefaultPassedGoal ;
      end if ;
      if AlertPrefix /= OSVVM_STRING_INIT_PARM_DETECT then
        AlertPrefixVar.Set(AlertPrefix) ;
      end if ;
      if LogPrefix /= OSVVM_STRING_INIT_PARM_DETECT then
        LogPrefixVar.Set(LogPrefix) ;
      end if ;
      if ReportPrefix /= OSVVM_STRING_INIT_PARM_DETECT then
        ReportPrefixVar.Set(ReportPrefix) ;
      end if ;
      if DoneName /= OSVVM_STRING_INIT_PARM_DETECT then
        DoneNameVar.Set(DoneName) ;
      end if ;
      if PassName /= OSVVM_STRING_INIT_PARM_DETECT then
        PassNameVar.Set(PassName) ;
      end if ;
      if FailName /= OSVVM_STRING_INIT_PARM_DETECT then
        FailNameVar.Set(FailName) ;
      end if ;
      if IdSeparator /= OSVVM_STRING_INIT_PARM_DETECT then
        IdSeparatorVar.Set(IdSeparator) ;
      end if ;
      if WriteTimeLast /= OPT_INIT_PARM_DETECT then
        WriteTimeLastVar := IsEnabled(WriteTimeLast) ;
      end if ;
      if TimeJustifyAmount >= 0 then
        TimeJustifyAmountVar := TimeJustifyAmount ;
      end if ;
    end procedure SetAlertLogOptions ;

    ------------------------------------------------------------
    procedure ReportAlertLogOptions is
    ------------------------------------------------------------
      variable buf : line ;
    begin
      -- Boolean Values
      swrite(buf, "ReportAlertLogOptions" & LF ) ;
      swrite(buf, "---------------------" & LF ) ;
      swrite(buf, "FailOnWarningVar:           " & to_string(FailOnWarningVar        ) & LF ) ;
      swrite(buf, "FailOnDisabledErrorsVar:    " & to_string(FailOnDisabledErrorsVar ) & LF ) ;
      swrite(buf, "FailOnRequirementErrorsVar: " & to_string(FailOnRequirementErrorsVar ) & LF ) ;

      swrite(buf, "ReportHierarchyVar:         " & to_string(ReportHierarchyVar      ) & LF ) ;
      swrite(buf, "FoundReportHierVar:         " & to_string(FoundReportHierVar      ) & LF ) ; -- Not set by user
      swrite(buf, "FoundAlertHierVar:          " & to_string(FoundAlertHierVar       ) & LF ) ; -- Not set by user
      swrite(buf, "WriteAlertErrorCountVar:    " & to_string(WriteAlertErrorCountVar ) & LF ) ;
      swrite(buf, "WriteAlertLevelVar:         " & to_string(WriteAlertLevelVar      ) & LF ) ;
      swrite(buf, "WriteAlertNameVar:          " & to_string(WriteAlertNameVar       ) & LF ) ;
      swrite(buf, "WriteAlertTimeVar:          " & to_string(WriteAlertTimeVar       ) & LF ) ;
      swrite(buf, "WriteLogErrorCountVar:      " & to_string(WriteLogErrorCountVar   ) & LF ) ;
      swrite(buf, "WriteLogLevelVar:           " & to_string(WriteLogLevelVar        ) & LF ) ;
      swrite(buf, "WriteLogNameVar:            " & to_string(WriteLogNameVar         ) & LF ) ;
      swrite(buf, "WriteLogTimeVar:            " & to_string(WriteLogTimeVar         ) & LF ) ;
      swrite(buf, "PrintPassedVar:             " & to_string(PrintPassedVar    ) & LF ) ;
      swrite(buf, "PrintAffirmationsVar:       " & to_string(PrintAffirmationsVar    ) & LF ) ;
      swrite(buf, "PrintDisabledAlertsVar:     " & to_string(PrintDisabledAlertsVar  ) & LF ) ;
      swrite(buf, "PrintRequirementsVar:       " & to_string(PrintRequirementsVar    ) & LF ) ;
      swrite(buf, "PrintIfHaveRequirementsVar: " & to_string(PrintIfHaveRequirementsVar  ) & LF ) ;

      -- String
      swrite(buf, "AlertPrefixVar:             " & string'(AlertPrefixVar.Get(OSVVM_DEFAULT_ALERT_PREFIX))  & LF ) ;
      swrite(buf, "LogPrefixVar:               " & string'(LogPrefixVar.Get(OSVVM_DEFAULT_LOG_PREFIX))      & LF ) ;
      swrite(buf, "ReportPrefixVar:            " & ResolveOsvvmWritePrefix(ReportPrefixVar.GetOpt) & LF ) ;
      swrite(buf, "DoneNameVar:                " & ResolveOsvvmDoneName(DoneNameVar.GetOpt)        & LF ) ;
      swrite(buf, "PassNameVar:                " & ResolveOsvvmPassName(PassNameVar.GetOpt)        & LF ) ;
      swrite(buf, "FailNameVar:                " & ResolveOsvvmFailName(FailNameVar.GetOpt)        & LF ) ;
      swrite(buf, "WriteTimeLastVar:           " & to_string(WriteTimeLastVar         ) & LF ) ;
      swrite(buf, "TimeJustifyAmountVar:       " & to_string(TimeJustifyAmountVar     ) & LF ) ;
      writeline(buf) ;
    end procedure ReportAlertLogOptions ;

    ------------------------------------------------------------
    impure function GetAlertLogFailOnWarning        return OsvvmOptionsType is
    ------------------------------------------------------------
    begin
      return to_OsvvmOptionsType(FailOnWarningVar) ;
    end function GetAlertLogFailOnWarning ;

    ------------------------------------------------------------
    impure function GetAlertLogFailOnDisabledErrors return OsvvmOptionsType is
    ------------------------------------------------------------
    begin
      return to_OsvvmOptionsType(FailOnDisabledErrorsVar) ;
    end function GetAlertLogFailOnDisabledErrors ;

    ------------------------------------------------------------
    impure function GetAlertLogFailOnRequirementErrors return OsvvmOptionsType is
    ------------------------------------------------------------
    begin
      return to_OsvvmOptionsType(FailOnRequirementErrorsVar) ;
    end function GetAlertLogFailOnRequirementErrors ;

    ------------------------------------------------------------
    impure function GetAlertLogReportHierarchy      return OsvvmOptionsType is
    ------------------------------------------------------------
    begin
      return to_OsvvmOptionsType(ReportHierarchyVar) ;
    end function GetAlertLogReportHierarchy ;

    ------------------------------------------------------------
    impure function GetAlertLogFoundReportHier       return boolean is
    ------------------------------------------------------------
    begin
      return FoundReportHierVar ;
    end function GetAlertLogFoundReportHier ;

    ------------------------------------------------------------
    impure function GetAlertLogFoundAlertHier       return boolean is
    ------------------------------------------------------------
    begin
      return FoundAlertHierVar ;
    end function GetAlertLogFoundAlertHier ;

    ------------------------------------------------------------
    impure function GetAlertLogWriteAlertErrorCount return OsvvmOptionsType is
    ------------------------------------------------------------
    begin
      return to_OsvvmOptionsType(WriteAlertErrorCountVar) ;
    end function GetAlertLogWriteAlertErrorCount ;

    ------------------------------------------------------------
    impure function GetAlertLogWriteAlertLevel      return OsvvmOptionsType is
    ------------------------------------------------------------
    begin
      return to_OsvvmOptionsType(WriteAlertLevelVar) ;
    end function GetAlertLogWriteAlertLevel ;

    ------------------------------------------------------------
    impure function GetAlertLogWriteAlertName       return OsvvmOptionsType is
    ------------------------------------------------------------
    begin
      return to_OsvvmOptionsType(WriteAlertNameVar) ;
    end function GetAlertLogWriteAlertName ;

    ------------------------------------------------------------
    impure function GetAlertLogWriteAlertTime       return OsvvmOptionsType is
    ------------------------------------------------------------
    begin
      return to_OsvvmOptionsType(WriteAlertTimeVar) ;
    end function GetAlertLogWriteAlertTime ;

    ------------------------------------------------------------
    impure function GetAlertLogWriteLogErrorCount return OsvvmOptionsType is
    ------------------------------------------------------------
    begin
      return to_OsvvmOptionsType(WriteLogErrorCountVar) ;
    end function GetAlertLogWriteLogErrorCount ;

    ------------------------------------------------------------
    impure function GetAlertLogWriteLogLevel        return OsvvmOptionsType is
    ------------------------------------------------------------
    begin
      return to_OsvvmOptionsType(WriteLogLevelVar) ;
    end function GetAlertLogWriteLogLevel ;

    ------------------------------------------------------------
    impure function GetAlertLogWriteLogName         return OsvvmOptionsType is
    ------------------------------------------------------------
    begin
      return to_OsvvmOptionsType(WriteLogNameVar) ;
    end function GetAlertLogWriteLogName ;

    ------------------------------------------------------------
    impure function GetAlertLogWriteLogTime         return OsvvmOptionsType is
    ------------------------------------------------------------
    begin
      return to_OsvvmOptionsType(WriteLogTimeVar) ;
    end function GetAlertLogWriteLogTime ;

    ------------------------------------------------------------
    impure function GetAlertLogPrintPassed    return OsvvmOptionsType is
    ------------------------------------------------------------
    begin
      return to_OsvvmOptionsType(PrintPassedVar) ;
    end function GetAlertLogPrintPassed ;

    ------------------------------------------------------------
    impure function GetAlertLogPrintAffirmations    return OsvvmOptionsType is
    ------------------------------------------------------------
    begin
      return to_OsvvmOptionsType(PrintAffirmationsVar) ;
    end function GetAlertLogPrintAffirmations ;

    ------------------------------------------------------------
    impure function GetAlertLogPrintDisabledAlerts  return OsvvmOptionsType is
    ------------------------------------------------------------
    begin
      return to_OsvvmOptionsType(PrintDisabledAlertsVar) ;
    end function GetAlertLogPrintDisabledAlerts ;

    ------------------------------------------------------------
    impure function GetAlertLogPrintRequirements    return OsvvmOptionsType is
    ------------------------------------------------------------
    begin
      return to_OsvvmOptionsType(PrintRequirementsVar) ;
    end function GetAlertLogPrintRequirements ;

    ------------------------------------------------------------
    impure function GetAlertLogPrintIfHaveRequirements    return OsvvmOptionsType is
    ------------------------------------------------------------
    begin
      return to_OsvvmOptionsType(PrintIfHaveRequirementsVar) ;
    end function GetAlertLogPrintIfHaveRequirements ;

    ------------------------------------------------------------
    impure function GetAlertLogDefaultPassedGoal    return integer is
    ------------------------------------------------------------
    begin
      return DefaultPassedGoalVar ;
    end function GetAlertLogDefaultPassedGoal ;

    ------------------------------------------------------------
    impure function GetAlertLogAlertPrefix          return string is
    ------------------------------------------------------------
    begin
      return AlertPrefixVar.Get(OSVVM_DEFAULT_ALERT_PREFIX) ;
    end function GetAlertLogAlertPrefix ;

    ------------------------------------------------------------
    impure function GetAlertLogLogPrefix            return string is
    ------------------------------------------------------------
    begin
      return LogPrefixVar.Get(OSVVM_DEFAULT_LOG_PREFIX) ;
    end function GetAlertLogLogPrefix ;

    ------------------------------------------------------------
    impure function GetAlertLogReportPrefix return string is
    ------------------------------------------------------------
    begin
      return ResolveOsvvmWritePrefix(ReportPrefixVar.GetOpt) ;
    end function GetAlertLogReportPrefix ;

    ------------------------------------------------------------
    impure function GetAlertLogDoneName return string is
    ------------------------------------------------------------
    begin
      return ResolveOsvvmDoneName(DoneNameVar.GetOpt) ;
    end function GetAlertLogDoneName ;

    ------------------------------------------------------------
    impure function GetAlertLogPassName return string is
    ------------------------------------------------------------
    begin
      return ResolveOsvvmPassName(PassNameVar.GetOpt) ;
    end function GetAlertLogPassName ;

    ------------------------------------------------------------
    impure function GetAlertLogFailName return string is
    ------------------------------------------------------------
    begin
      return ResolveOsvvmFailName(FailNameVar.GetOpt) ;
    end function GetAlertLogFailName ;

    ------------------------------------------------------------
    impure function GetAlertLogWriteTimeLast        return OsvvmOptionsType is
    ------------------------------------------------------------
    begin
      return to_OsvvmOptionsType(WriteTimeLastVar) ;
    end function GetAlertLogWriteTimeLast ;


  end protected body AlertLogStructPType ;



  shared variable AlertLogStruct : AlertLogStructPType ;

-- synthesis translate_on

--- ///////////////////////////////////////////////////////////////////////////
--- ///////////////////////////////////////////////////////////////////////////
--- ///////////////////////////////////////////////////////////////////////////

  ------------------------------------------------------------
  procedure Alert(
  ------------------------------------------------------------
    AlertLogID   : AlertLogIDType ;
    Message      : string  ;
    Level        : AlertType := ERROR
  ) is
  begin
    -- synthesis translate_off
    AlertLogStruct.Alert(AlertLogID, Message, Level) ;
    -- synthesis translate_on
  end procedure alert ;

  ------------------------------------------------------------
  procedure Alert( Message : string ; Level : AlertType := ERROR ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message, Level) ;
    -- synthesis translate_on
  end procedure alert ;

  ------------------------------------------------------------
  procedure IncAlertCount(
  ------------------------------------------------------------
    AlertLogID   : AlertLogIDType ;
    Level        : AlertType := ERROR
  ) is
  begin
    -- synthesis translate_off
    AlertLogStruct.IncAlertCount(AlertLogID, Level) ;
    -- synthesis translate_on
  end procedure IncAlertCount ;

  ------------------------------------------------------------
  procedure IncAlertCount( Level : AlertType := ERROR ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.IncAlertCount(ALERT_DEFAULT_ID, Level) ;
    -- synthesis translate_on
  end procedure IncAlertCount ;


  ------------------------------------------------------------
  procedure AlertIf( AlertLogID  : AlertLogIDType ; condition : boolean ; Message : string ; Level : AlertType := ERROR ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if condition then
      AlertLogStruct.Alert(AlertLogID , Message, Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIf ;

  ------------------------------------------------------------
  procedure AlertIf( condition : boolean ; Message : string ; Level : AlertType := ERROR ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if condition then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID , Message, Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIf ;

  ------------------------------------------------------------
  -- useful in a loop:  exit when AlertIf( not ReadValid, failure, "Read Failed") ;
  impure function  AlertIf( AlertLogID  : AlertLogIDType ; condition : boolean ; Message : string ; Level : AlertType := ERROR ) return boolean is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if condition then
      AlertLogStruct.Alert(AlertLogID , Message, Level) ;
    end if ;
    -- synthesis translate_on
    return condition ;
  end function AlertIf ;

  ------------------------------------------------------------
  impure function  AlertIf( condition : boolean ; Message : string ; Level : AlertType := ERROR ) return boolean is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if condition then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message, Level) ;
    end if ;
    -- synthesis translate_on
    return condition ;
  end function AlertIf ;

  ------------------------------------------------------------
  procedure AlertIfNot( AlertLogID  : AlertLogIDType ; condition : boolean ; Message : string ; Level : AlertType := ERROR ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if not condition then
      AlertLogStruct.Alert(AlertLogID, Message, Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfNot ;

  ------------------------------------------------------------
  procedure AlertIfNot( condition : boolean ; Message : string ; Level : AlertType := ERROR ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if not condition then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message, Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfNot ;

  ------------------------------------------------------------
  -- useful in a loop:  exit when AlertIfNot( not ReadValid, failure, "Read Failed") ;
  impure function  AlertIfNot( AlertLogID  : AlertLogIDType ; condition : boolean ; Message : string ; Level : AlertType := ERROR ) return boolean is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if not condition then
      AlertLogStruct.Alert(AlertLogID, Message, Level) ;
    end if ;
    -- synthesis translate_on
    return not condition ;
  end function AlertIfNot ;

  ------------------------------------------------------------
  impure function  AlertIfNot( condition : boolean ; Message : string ; Level : AlertType := ERROR ) return boolean is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if not condition then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message, Level) ;
    end if ;
    -- synthesis translate_on
    return not condition ;
  end function AlertIfNot ;


  ------------------------------------------------------------
  -- AlertIfEqual with AlertLogID
  ------------------------------------------------------------
  procedure AlertIfEqual( AlertLogID : AlertLogIDType ; L, R : std_logic ;        Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if MetaMatch(L, R) then
      AlertLogStruct.Alert(AlertLogID, Message & " L = R,  L = " & to_string(L) & "   R = " & to_string(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfEqual ;

  ------------------------------------------------------------
  procedure AlertIfEqual( AlertLogID : AlertLogIDType ; L, R : std_logic_vector ; Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if MetaMatch(L, R) then
      AlertLogStruct.Alert(AlertLogID, Message & " L = R,  L = " & to_hxstring(L) & "   R = " & to_hxstring(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfEqual ;

  ------------------------------------------------------------
  procedure AlertIfEqual( AlertLogID : AlertLogIDType ; L, R : unsigned ;         Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if MetaMatch(L, R) then
      AlertLogStruct.Alert(AlertLogID, Message & " L = R,  L = " & to_hxstring(L) & "   R = " & to_hxstring(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfEqual ;

  ------------------------------------------------------------
  procedure AlertIfEqual( AlertLogID : AlertLogIDType ; L, R : signed ;           Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if MetaMatch(L, R) then
      AlertLogStruct.Alert(AlertLogID, Message & " L = R,  L = " & to_hxstring(L) & "   R = " & to_hxstring(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfEqual ;

  ------------------------------------------------------------
  procedure AlertIfEqual( AlertLogID : AlertLogIDType ; L, R : integer ;          Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L = R then
      AlertLogStruct.Alert(AlertLogID, Message & " L = R,  L = " & to_string(L) & "   R = " & to_string(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfEqual ;

  ------------------------------------------------------------
  procedure AlertIfEqual( AlertLogID : AlertLogIDType ; L, R : real ;             Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L = R then
      AlertLogStruct.Alert(AlertLogID, Message & " L = R,  L = " & to_string(L, 4) & "   R = " & to_string(R, 4), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfEqual ;

  ------------------------------------------------------------
  procedure AlertIfEqual( AlertLogID : AlertLogIDType ; L, R : character ;        Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L = R then
      AlertLogStruct.Alert(AlertLogID, Message & " L = R,  L = " & L & "   R = " & R, Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfEqual ;

  ------------------------------------------------------------
  procedure AlertIfEqual( AlertLogID : AlertLogIDType ; L, R : string ;           Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L = R then
      AlertLogStruct.Alert(AlertLogID, Message & " L = R,  L = " & L & "   R = " & R, Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfEqual ;

  ------------------------------------------------------------
  procedure AlertIfEqual( AlertLogID : AlertLogIDType ; L, R : time ;             Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L = R then
      AlertLogStruct.Alert(AlertLogID, Message & " L = R,  L = " & to_string(L, GetOsvvmDefaultTimeUnits)
                                                     & "   R = " & to_string(R, GetOsvvmDefaultTimeUnits), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfEqual ;


  ------------------------------------------------------------
  -- AlertIfEqual without AlertLogID
  ------------------------------------------------------------
  procedure AlertIfEqual( L, R : std_logic ;        Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if MetaMatch(L, R) then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message & " L = R,  L = " & to_string(L) & "   R = " & to_string(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfEqual ;

  ------------------------------------------------------------
  procedure AlertIfEqual( L, R : std_logic_vector ; Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if MetaMatch(L, R) then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message & " L = R,  L = " & to_hxstring(L) & "   R = " & to_hxstring(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfEqual ;

  ------------------------------------------------------------
  procedure AlertIfEqual( L, R : unsigned ;         Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if MetaMatch(L, R) then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message & " L = R,  L = " & to_hxstring(L) & "   R = " & to_hxstring(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfEqual ;

  ------------------------------------------------------------
  procedure AlertIfEqual( L, R : signed ;           Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if MetaMatch(L, R) then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message & " L = R,  L = " & to_hxstring(L) & "   R = " & to_hxstring(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfEqual ;

  ------------------------------------------------------------
  procedure AlertIfEqual( L, R : integer ;          Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L = R then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message & " L = R,  L = " & to_string(L) & "   R = " & to_string(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfEqual ;

  ------------------------------------------------------------
  procedure AlertIfEqual( L, R : real ;             Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L = R then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message & " L = R,  L = " & to_string(L, 4) & "   R = " & to_string(R, 4), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfEqual ;

  ------------------------------------------------------------
  procedure AlertIfEqual( L, R : character ;        Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L = R then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message & " L = R,  L = " & L & "   R = " & R, Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfEqual ;

  ------------------------------------------------------------
  procedure AlertIfEqual( L, R : string ;           Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L = R then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message & " L = R,  L = " & L & "   R = " & R, Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfEqual ;

  ------------------------------------------------------------
  procedure AlertIfEqual( L, R : time ;             Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L = R then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message & " L = R,  L = " & to_string(L, GetOsvvmDefaultTimeUnits)
                                                           & "   R = " & to_string(R, GetOsvvmDefaultTimeUnits), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfEqual ;


  ------------------------------------------------------------
  -- AlertIfNotEqual with AlertLogID
  ------------------------------------------------------------
  procedure AlertIfNotEqual( AlertLogID : AlertLogIDType ; L, R : std_logic ;        Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if not MetaMatch(L, R) then
      AlertLogStruct.Alert(AlertLogID, Message & " L /= R,  L = " & to_string(L) & "   R = " & to_string(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfNotEqual ;

  ------------------------------------------------------------
  procedure AlertIfNotEqual( AlertLogID : AlertLogIDType ; L, R : std_logic_vector ; Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if not MetaMatch(L, R) then
      AlertLogStruct.Alert(AlertLogID, Message & " L /= R,  L = " & to_hxstring(L) & "   R = " & to_hxstring(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfNotEqual ;

  ------------------------------------------------------------
  procedure AlertIfNotEqual( AlertLogID : AlertLogIDType ; L, R : unsigned ;         Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if  not MetaMatch(L, R) then
      AlertLogStruct.Alert(AlertLogID, Message & " L /= R,  L = " & to_hxstring(L) & "   R = " & to_hxstring(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfNotEqual ;

  ------------------------------------------------------------
  procedure AlertIfNotEqual( AlertLogID : AlertLogIDType ; L, R : signed ;           Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if not MetaMatch(L, R) then
      AlertLogStruct.Alert(AlertLogID, Message & " L /= R,  L = " & to_hxstring(L) & "   R = " & to_hxstring(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfNotEqual ;

  ------------------------------------------------------------
  procedure AlertIfNotEqual( AlertLogID : AlertLogIDType ; L, R : integer ;          Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L /= R then
      AlertLogStruct.Alert(AlertLogID, Message & " L /= R,  L = " & to_string(L) & "   R = " & to_string(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfNotEqual ;

  ------------------------------------------------------------
  procedure AlertIfNotEqual( AlertLogID : AlertLogIDType ; L, R : real ;             Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L /= R then
      AlertLogStruct.Alert(AlertLogID, Message & " L /= R,  L = " & to_string(L, 4) & "   R = " & to_string(R, 4), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfNotEqual ;

  ------------------------------------------------------------
  procedure AlertIfNotEqual( AlertLogID : AlertLogIDType ; L, R : character ;        Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L /= R then
      AlertLogStruct.Alert(AlertLogID, Message & " L /= R,  L = " & L & "   R = " & R, Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfNotEqual ;

  ------------------------------------------------------------
  procedure AlertIfNotEqual( AlertLogID : AlertLogIDType ; L, R : string ;           Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L /= R then
      AlertLogStruct.Alert(AlertLogID, Message & " L /= R,  L = " & L & "   R = " & R, Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfNotEqual ;

  ------------------------------------------------------------
  procedure AlertIfNotEqual( AlertLogID : AlertLogIDType ; L, R : time ;             Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L /= R then
      AlertLogStruct.Alert(AlertLogID, Message & " L /= R,  L = " & to_string(L, GetOsvvmDefaultTimeUnits) &
                                                        "   R = " & to_string(R, GetOsvvmDefaultTimeUnits), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfNotEqual ;


  ------------------------------------------------------------
  -- AlertIfNotEqual without AlertLogID
  ------------------------------------------------------------
  procedure AlertIfNotEqual( L, R : std_logic ;        Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if not MetaMatch(L, R) then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message & " L /= R,  L = " & to_string(L) & "   R = " & to_string(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfNotEqual ;

  ------------------------------------------------------------
  procedure AlertIfNotEqual( L, R : std_logic_vector ; Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if not MetaMatch(L, R) then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message & " L /= R,  L = " & to_hxstring(L) & "   R = " & to_hxstring(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfNotEqual ;

  ------------------------------------------------------------
  procedure AlertIfNotEqual( L, R : unsigned ;         Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if not MetaMatch(L, R) then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message & " L /= R,  L = " & to_hxstring(L) & "   R = " & to_hxstring(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfNotEqual ;

  ------------------------------------------------------------
  procedure AlertIfNotEqual( L, R : signed ;           Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if not MetaMatch(L, R) then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message & " L /= R,  L = " & to_hxstring(L) & "   R = " & to_hxstring(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfNotEqual ;

  ------------------------------------------------------------
  procedure AlertIfNotEqual( L, R : integer ;          Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L /= R then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message & " L /= R,  L = " & to_string(L) & "   R = " & to_string(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfNotEqual ;

  ------------------------------------------------------------
  procedure AlertIfNotEqual( L, R : real ;             Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L /= R then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message & " L /= R,  L = " & to_string(L, 4) & "   R = " & to_string(R, 4), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfNotEqual ;

  ------------------------------------------------------------
  procedure AlertIfNotEqual( L, R : character ;        Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L /= R then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message & " L /= R,  L = " & L & "   R = " & R, Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfNotEqual ;

  ------------------------------------------------------------
  procedure AlertIfNotEqual( L, R : string ;           Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L /= R then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message & " L /= R,  L = " & L & "   R = " & R, Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfNotEqual ;

  ------------------------------------------------------------
  procedure AlertIfNotEqual( L, R : time ;           Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L /= R then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message & " L /= R,  L = " & to_string(L, GetOsvvmDefaultTimeUnits) &
                                                              "   R = " & to_string(R, GetOsvvmDefaultTimeUnits), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfNotEqual ;

  ------------------------------------------------------------
  -- Local
  function LocalDiff (Line1, Line2 : string) return boolean is
  -- Simple diff.  Move to string handling functions?
  ------------------------------------------------------------
    alias aLine1 : string (1 to Line1'length) is Line1 ;
    alias aLine2 : string (1 to Line2'length) is Line2 ;
    variable EndLine1 : integer := Line1'length;
    variable EndLine2 : integer := Line2'length;
  begin
    -- Strip off any windows or unix end of line characters
    for i in Line1'length downto 1 loop
      exit when aLine1(i) /= LF and aLine1(i) /= CR ;
      EndLine1 := i - 1;
    end loop ;
    for i in Line2'length downto 1 loop
      exit when aLine2(i) /= LF and aLine2(i) /= CR ;
      EndLine2 := i - 1;
    end loop ;

    return aLine1(1 to EndLine1) /= aLine2(1 to EndLine2) ;
  end function LocalDiff ;

  ------------------------------------------------------------
  -- Local
  procedure LocalAlertIfDiff (AlertLogID : AlertLogIDType ; file File1, File2 : text; Message : string ; Level : AlertType ; Valid : out boolean ) is
  ------------------------------------------------------------
    variable Buf1, Buf2 : line ;
    variable File1Done, File2Done : boolean ;
    variable LineCount : integer := 0 ;
  begin
    -- synthesis translate_off
    ReadLoop : loop
      File1Done := EndFile(File1) ;
      File2Done := EndFile(File2) ;
      exit ReadLoop when File1Done or File2Done ;

      ReadLine(File1, Buf1) ;
      ReadLine(File2, Buf2) ;
      LineCount := LineCount + 1 ;

--      if Buf1.all /= Buf2.all then  -- fails when use Windows file in Unix
      if LocalDiff(Buf1.all, Buf2.all) then
        AlertLogStruct.Alert(AlertLogID , Message & " File miscompare on line " & to_string(LineCount), Level) ;
        exit ReadLoop ;
      end if ;
    end loop ReadLoop ;
    if File1Done /= File2Done then
      if not File1Done then
        AlertLogStruct.Alert(AlertLogID , Message & " File1 longer than File2 " & to_string(LineCount), Level) ;
      end if ;
      if not File2Done then
        AlertLogStruct.Alert(AlertLogID , Message & " File2 longer than File1 " & to_string(LineCount), Level) ;
      end if ;
    end if;
    if File1Done and File2Done then
      Valid := TRUE ;
    else
      Valid := FALSE ;
    end if ;
    -- synthesis translate_on
  end procedure LocalAlertIfDiff ;

  ------------------------------------------------------------
  -- Local
  procedure LocalAlertIfDiff (AlertLogID : AlertLogIDType ; Name1, Name2 : string; Message : string ; Level : AlertType ; Valid : out boolean ) is
  -- Open files and call AlertIfDiff[text, ...]
  ------------------------------------------------------------
    file FileID1, FileID2 : text ;
    variable status1, status2 : file_open_status ;
    constant RESOLVED_MESSAGE : string := IfElse(Message = "", "", Message & " ") ;
  begin
    -- synthesis translate_off
    Valid := FALSE ;
    file_open(status1, FileID1, Name1, READ_MODE) ;
    file_open(status2, FileID2, Name2, READ_MODE) ;
    if status1 = OPEN_OK and status2 = OPEN_OK then
      LocalAlertIfDiff (AlertLogID, FileID1, FileID2, RESOLVED_MESSAGE & "diff " & Name1 & "  " & Name2 & ", ", Level, Valid) ;

    else
      if status1 /= OPEN_OK then
        AlertLogStruct.Alert(AlertLogID , RESOLVED_MESSAGE & "File, " & Name1 & ", did not open", Level) ;
      end if ;
      if status2 /= OPEN_OK then
        AlertLogStruct.Alert(AlertLogID , RESOLVED_MESSAGE & "File, " & Name2 & ", did not open", Level) ;
      end if ;
    end if;
    -- synthesis translate_on
  end procedure LocalAlertIfDiff ;

  ------------------------------------------------------------
  procedure AlertIfDiff (AlertLogID : AlertLogIDType ; Name1, Name2 : string; Message : string := "" ; Level : AlertType := ERROR ) is
  -- Open files and call AlertIfDiff[text, ...]
  ------------------------------------------------------------
    variable Valid : boolean ;
  begin
    -- synthesis translate_off
    LocalAlertIfDiff (AlertLogID, Name1, Name2, Message, Level, Valid) ;
    -- synthesis translate_on
  end procedure AlertIfDiff ;

  ------------------------------------------------------------
  procedure AlertIfDiff (Name1, Name2 : string; Message : string := "" ; Level : AlertType := ERROR ) is
  ------------------------------------------------------------
    variable Valid : boolean ;
  begin
    -- synthesis translate_off
    LocalAlertIfDiff (ALERT_DEFAULT_ID, Name1, Name2, Message, Level, Valid) ;
    -- synthesis translate_on
  end procedure AlertIfDiff ;

  ------------------------------------------------------------
  procedure AlertIfDiff (AlertLogID : AlertLogIDType ; file File1, File2 : text; Message : string := "" ; Level : AlertType := ERROR ) is
  -- Simple diff.
  ------------------------------------------------------------
    variable Valid : boolean ;
  begin
    -- synthesis translate_off
    LocalAlertIfDiff (AlertLogID, File1, File2, Message, Level, Valid ) ;
    -- synthesis translate_on
  end procedure AlertIfDiff ;

  ------------------------------------------------------------
  procedure AlertIfDiff (file File1, File2 : text; Message : string := "" ; Level : AlertType := ERROR ) is
  ------------------------------------------------------------
    variable Valid : boolean ;
  begin
    -- synthesis translate_off
    LocalAlertIfDiff (ALERT_DEFAULT_ID, File1, File2, Message, Level, Valid ) ;
    -- synthesis translate_on
  end procedure AlertIfDiff ;

  ------------------------------------------------------------
  procedure AffirmIf(
  ------------------------------------------------------------
    AlertLogID       : AlertLogIDType ;
    condition        : boolean ;
    ReceivedMessage  : string ;
    ExpectedMessage  : string ;
    Enable           : boolean  := FALSE   -- override internal enable
  ) is
  begin
    -- synthesis translate_off
    if condition then
      -- PASSED.  Count affirmations and PASSED internal to LOG to catch all of them
      AlertLogStruct.Log(AlertLogID, ReceivedMessage, PASSED, Enable) ;
    else
      AlertLogStruct.IncAffirmCount(AlertLogID) ;  -- count the affirmation
      AlertLogStruct.Alert(AlertLogID, ReceivedMessage & ' ' & ExpectedMessage, ERROR) ;
    end if ;
    -- synthesis translate_on
  end procedure AffirmIf ;

  ------------------------------------------------------------
  procedure AffirmIf( condition : boolean ; ReceivedMessage, ExpectedMessage : string ; Enable : boolean := FALSE ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(ALERT_DEFAULT_ID, condition, ReceivedMessage, ExpectedMessage, Enable) ;
    -- synthesis translate_on
  end procedure AffirmIf ;

  ------------------------------------------------------------
  impure function AffirmIf( AlertLogID : AlertLogIDType ; condition : boolean ; ReceivedMessage, ExpectedMessage : string ; Enable : boolean := FALSE ) return boolean is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(AlertLogID, condition, ReceivedMessage, ExpectedMessage, Enable) ;
    -- synthesis translate_on
    return condition ;
  end function AffirmIf ;

  ------------------------------------------------------------
  impure function AffirmIf( condition : boolean ; ReceivedMessage, ExpectedMessage : string ; Enable : boolean := FALSE ) return boolean is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(ALERT_DEFAULT_ID, condition, ReceivedMessage, ExpectedMessage, Enable) ;
    -- synthesis translate_on
    return condition ;
  end function AffirmIf ;


  ------------------------------------------------------------
  procedure AffirmIf(
  ------------------------------------------------------------
    AlertLogID   : AlertLogIDType ;
    condition    : boolean ;
    Message      : string ;
    Enable       : boolean  := FALSE   -- override internal enable
  ) is
  begin
    -- synthesis translate_off
    if condition then
      -- PASSED.  Count affirmations and PASSED internal to LOG to catch all of them
      AlertLogStruct.Log(AlertLogID, Message, PASSED, Enable) ;
    else
      AlertLogStruct.IncAffirmCount(AlertLogID) ;  -- count the affirmation
      AlertLogStruct.Alert(AlertLogID, Message, ERROR) ;
    end if ;
    -- synthesis translate_on
  end procedure AffirmIf ;

  ------------------------------------------------------------
  procedure AffirmIf(condition : boolean ; Message : string ;  Enable : boolean := FALSE) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(ALERT_DEFAULT_ID, condition, Message, Enable) ;
    -- synthesis translate_on
  end procedure AffirmIf;

  ------------------------------------------------------------
  -- useful in a loop:  exit when AffirmIf( ID, not ReadValid, "Read Failed") ;
  impure function  AffirmIf( AlertLogID  : AlertLogIDType ; condition : boolean ; Message : string ; Enable : boolean := FALSE ) return boolean is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(AlertLogID, condition, Message, Enable) ;
    -- synthesis translate_on
    return condition ;
  end function AffirmIf ;

  ------------------------------------------------------------
  impure function  AffirmIf( condition : boolean ; Message : string ; Enable : boolean := FALSE ) return boolean is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(ALERT_DEFAULT_ID, condition, Message, Enable) ;
    -- synthesis translate_on
    return condition ;
  end function AffirmIf ;

  ------------------------------------------------------------
  ------------------------------------------------------------
  procedure AffirmIfNot( AlertLogID : AlertLogIDType ; condition : boolean ; ReceivedMessage, ExpectedMessage : string ; Enable : boolean := FALSE ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(AlertLogID, not condition, ReceivedMessage, ExpectedMessage, Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfNot ;

  ------------------------------------------------------------
  procedure AffirmIfNot( condition : boolean ; ReceivedMessage, ExpectedMessage : string ; Enable : boolean := FALSE ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(ALERT_DEFAULT_ID, not condition, ReceivedMessage, ExpectedMessage, Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfNot ;

  ------------------------------------------------------------
  -- useful in a loop:  exit when AffirmIfNot( not ReadValid, failure, "Read Failed") ;
  impure function  AffirmIfNot( AlertLogID  : AlertLogIDType ; condition : boolean ; ReceivedMessage, ExpectedMessage : string ; Enable : boolean := FALSE ) return boolean is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(AlertLogID, not condition, ReceivedMessage, ExpectedMessage, Enable) ;
    -- synthesis translate_on
    return not condition ;
  end function AffirmIfNot ;

  ------------------------------------------------------------
  impure function  AffirmIfNot( condition : boolean ; ReceivedMessage, ExpectedMessage : string ; Enable : boolean := FALSE ) return boolean is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(ALERT_DEFAULT_ID, not condition, ReceivedMessage, ExpectedMessage, Enable) ;
    -- synthesis translate_on
    return not condition ;
  end function AffirmIfNot ;

  ------------------------------------------------------------
  procedure AffirmIfNot( AlertLogID : AlertLogIDType ; condition : boolean ; Message : string ; Enable : boolean := FALSE ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(AlertLogID, not condition, Message, Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfNot ;

  ------------------------------------------------------------
  procedure AffirmIfNot( condition : boolean ; Message : string ; Enable : boolean := FALSE ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(ALERT_DEFAULT_ID, not condition, Message, Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfNot ;

  ------------------------------------------------------------
  -- useful in a loop:  exit when AffirmIfNot( not ReadValid, failure, "Read Failed") ;
  impure function  AffirmIfNot( AlertLogID  : AlertLogIDType ; condition : boolean ; Message : string ; Enable : boolean := FALSE ) return boolean is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(AlertLogID, not condition, Message, Enable) ;
    -- synthesis translate_on
    return not condition ;
  end function AffirmIfNot ;

  ------------------------------------------------------------
  impure function  AffirmIfNot( condition : boolean ; Message : string ; Enable : boolean := FALSE ) return boolean is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(ALERT_DEFAULT_ID, not condition, Message, Enable) ;
    -- synthesis translate_on
    return not condition ;
  end function AffirmIfNot ;


  ------------------------------------------------------------
  ------------------------------------------------------------
  procedure AffirmPassed( AlertLogID : AlertLogIDType ; Message : string ; Enable : boolean := FALSE ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(AlertLogID, TRUE, Message, Enable) ;
    -- synthesis translate_on
  end procedure AffirmPassed ;

  ------------------------------------------------------------
  procedure AffirmPassed( Message : string ; Enable : boolean := FALSE ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(ALERT_DEFAULT_ID, TRUE, Message, Enable) ;
    -- synthesis translate_on
  end procedure AffirmPassed ;

  ------------------------------------------------------------
  procedure AffirmError( AlertLogID : AlertLogIDType ; Message : string ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(AlertLogID, FALSE, Message, FALSE) ;
    -- synthesis translate_on
  end procedure AffirmError ;

  ------------------------------------------------------------
  procedure AffirmError( Message : string ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(ALERT_DEFAULT_ID, FALSE, Message, FALSE) ;
    -- synthesis translate_on
  end procedure AffirmError ;

  -- With AlertLogID
  ------------------------------------------------------------
  procedure AffirmIfEqual( AlertLogID : AlertLogIDType ; Received, Expected : boolean ;  Message : string := "" ; Enable : boolean := FALSE )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(AlertLogID, Received = Expected,
      Message & " Received : " & to_string(Received),
      "?= Expected : " & to_string(Expected),
      Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfEqual ;

  ------------------------------------------------------------
  procedure AffirmIfEqual( AlertLogID : AlertLogIDType ; Received, Expected : std_logic ;  Message : string := "" ; Enable : boolean := FALSE )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(AlertLogID, MetaMatch(Received, Expected),
      Message & " Received : " & to_string(Received),
      "?= Expected : " & to_string(Expected),
      Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfEqual ;

  ------------------------------------------------------------
  procedure AffirmIfEqual( AlertLogID : AlertLogIDType ; Received, Expected : std_logic_vector ; Message : string := "" ; Enable : boolean := FALSE )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(AlertLogID, MetaMatch(Received, Expected),
      Message & " Received : " & to_hxstring(Received),
      "?= Expected : " & to_hxstring(Expected),
      Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfEqual ;

  ------------------------------------------------------------
  procedure AffirmIfEqual( AlertLogID : AlertLogIDType ; Received, Expected : unsigned ; Message : string := "" ; Enable : boolean := FALSE )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(AlertLogID, MetaMatch(Received, Expected),
      Message & " Received : " & to_hxstring(Received),
      "?= Expected : " & to_hxstring(Expected),
      Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfEqual ;

  ------------------------------------------------------------
  procedure AffirmIfEqual( AlertLogID : AlertLogIDType ; Received, Expected : signed ; Message : string := "" ; Enable : boolean := FALSE )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(AlertLogID, MetaMatch(Received, Expected),
      Message & " Received : " & to_hxstring(Received),
      "?= Expected : " & to_hxstring(Expected),
      Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfEqual ;

  ------------------------------------------------------------
  procedure AffirmIfEqual( AlertLogID : AlertLogIDType ; Received, Expected : integer ; Message : string := "" ; Enable : boolean := FALSE )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(AlertLogID, Received = Expected,
      Message & " Received : " & to_string(Received),
      "= Expected : " & to_string(Expected),
      Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfEqual ;

  ------------------------------------------------------------
  procedure AffirmIfEqual( AlertLogID : AlertLogIDType ; Received, Expected : real ; Message : string := "" ; Enable : boolean := FALSE )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(AlertLogID, Received = Expected,
      Message & " Received : " & to_string(Received, 4),
      "= Expected : " & to_string(Expected, 4),
      Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfEqual ;

  ------------------------------------------------------------
  procedure AffirmIfEqual( AlertLogID : AlertLogIDType ; Received, Expected : character ; Message : string := "" ; Enable : boolean := FALSE )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(AlertLogID, Received = Expected,
      Message & " Received : " & to_string(Received),
      "= Expected : " & to_string(Expected),
      Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfEqual ;

  ------------------------------------------------------------
  procedure AffirmIfEqual( AlertLogID : AlertLogIDType ; Received, Expected : string ; Message : string := "" ; Enable : boolean := FALSE )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(AlertLogID, Received = Expected,
      Message & " Received : " & Received,
      "= Expected : " & Expected,
      Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfEqual ;

  ------------------------------------------------------------
  procedure AffirmIfEqual( AlertLogID : AlertLogIDType ; Received, Expected : time ; Message : string := "" ; Enable : boolean := FALSE )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(AlertLogID, Received = Expected,
      Message & " Received : " & to_string(Received, GetOsvvmDefaultTimeUnits),
               "= Expected : " & to_string(Expected, GetOsvvmDefaultTimeUnits),
      Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfEqual ;

  -- Without AlertLogID
  ------------------------------------------------------------
  procedure AffirmIfEqual( Received, Expected : boolean ;  Message : string := "" ; Enable : boolean := FALSE )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(ALERT_DEFAULT_ID, Received = Expected,
      Message & " Received : " & to_string(Received),
      "?= Expected : " & to_string(Expected),
      Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfEqual ;

  ------------------------------------------------------------
  procedure AffirmIfEqual( Received, Expected : std_logic ;  Message : string := "" ; Enable : boolean := FALSE )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(ALERT_DEFAULT_ID, MetaMatch(Received, Expected),
      Message & " Received : " & to_string(Received),
      "?= Expected : " & to_string(Expected),
      Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfEqual ;

  ------------------------------------------------------------
  procedure AffirmIfEqual( Received, Expected : std_logic_vector ; Message : string := "" ; Enable : boolean := FALSE )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(ALERT_DEFAULT_ID, MetaMatch(Received, Expected),
      Message & " Received : " & to_hxstring(Received),
      "?= Expected : " & to_hxstring(Expected),
      Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfEqual ;

  ------------------------------------------------------------
  procedure AffirmIfEqual( Received, Expected : unsigned ; Message : string := "" ; Enable : boolean := FALSE )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(ALERT_DEFAULT_ID, MetaMatch(Received, Expected),
      Message & " Received : " & to_hxstring(Received),
      "?= Expected : " & to_hxstring(Expected),
      Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfEqual ;

  ------------------------------------------------------------
  procedure AffirmIfEqual( Received, Expected : signed ; Message : string := "" ; Enable : boolean := FALSE )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(ALERT_DEFAULT_ID, MetaMatch(Received, Expected),
      Message & " Received : " & to_hxstring(Received),
      "?= Expected : " & to_hxstring(Expected),
      Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfEqual ;

  ------------------------------------------------------------
  procedure AffirmIfEqual( Received, Expected : integer ; Message : string := "" ; Enable : boolean := FALSE )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(ALERT_DEFAULT_ID, Received = Expected,
      Message & " Received : " & to_string(Received),
      "= Expected : " & to_string(Expected),
      Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfEqual ;

  ------------------------------------------------------------
  procedure AffirmIfEqual( Received, Expected : real ; Message : string := "" ; Enable : boolean := FALSE )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(ALERT_DEFAULT_ID, Received = Expected,
      Message & " Received : " & to_string(Received, 4),
      "= Expected : " & to_string(Expected, 4),
      Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfEqual ;

  ------------------------------------------------------------
  procedure AffirmIfEqual( Received, Expected : character ; Message : string := "" ; Enable : boolean := FALSE )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(ALERT_DEFAULT_ID, Received = Expected,
      Message & " Received : " & to_string(Received),
      "= Expected : " & to_string(Expected),
      Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfEqual ;

  ------------------------------------------------------------
  procedure AffirmIfEqual( Received, Expected : string ; Message : string := "" ; Enable : boolean := FALSE )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(ALERT_DEFAULT_ID, Received = Expected,
      Message & " Received : " & Received,
      "= Expected : " & Expected,
      Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfEqual ;

  ------------------------------------------------------------
  procedure AffirmIfEqual( Received, Expected : time ; Message : string := "" ; Enable : boolean := FALSE )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(ALERT_DEFAULT_ID, Received = Expected,
      Message & " Received : "  & to_string(Received, GetOsvvmDefaultTimeUnits),
                "= Expected : " & to_string(Expected, GetOsvvmDefaultTimeUnits),
      Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfEqual ;

  ------------------------------------------------------------
  procedure AffirmIfNotDiff (AlertLogID : AlertLogIDType ; Name1, Name2 : string; Message : string := "" ; Enable : boolean := FALSE ) is
  -- Open files and call AffirmIfNotDiff[text, ...]
  ------------------------------------------------------------
    variable Valid : boolean ;
  begin
    -- synthesis translate_off
    LocalAlertIfDiff (AlertLogID, Name1, Name2, Message, ERROR, Valid) ;
    if Valid then
      AlertLogStruct.Log(AlertLogID, Message & " " & Name1 & "  " & Name2, PASSED, Enable) ;
    else
      AlertLogStruct.IncAffirmCount(AlertLogID) ;  -- count the affirmation
      -- Alert already signaled by LocalAlertIfDiff
    end if ;
    -- synthesis translate_on
  end procedure AffirmIfNotDiff ;

  ------------------------------------------------------------
  procedure AffirmIfNotDiff (Name1, Name2 : string; Message : string := "" ; Enable : boolean := FALSE ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIfNotDiff(ALERT_DEFAULT_ID, Name1, Name2, Message, Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfNotDiff ;

  ------------------------------------------------------------
  procedure AffirmIfNotDiff (AlertLogID : AlertLogIDType ; file File1, File2 : text; Message : string := "" ; Enable : boolean := FALSE ) is
  -- Simple diff.
  ------------------------------------------------------------
    variable Valid : boolean ;
  begin
    -- synthesis translate_off
    LocalAlertIfDiff (AlertLogID, File1, File2, Message, ERROR, Valid ) ;
    if Valid then
      AlertLogStruct.Log(AlertLogID, Message, PASSED, Enable) ;
    else
      AlertLogStruct.IncAffirmCount(AlertLogID) ;  -- count the affirmation
      -- Alert already signaled by LocalAlertIfDiff
    end if ;
    -- synthesis translate_on
  end procedure AffirmIfNotDiff ;

  ------------------------------------------------------------
  procedure AffirmIfNotDiff (file File1, File2 : text; Message : string := "" ; Enable : boolean := FALSE ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIfNotDiff(ALERT_DEFAULT_ID, File1, File2, Message, Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfNotDiff ;

  ------------------------------------------------------------
-- DEPRECATED - naming polarity is incorrect.   Should be AffirmIfNotDiff
  procedure AffirmIfDiff (AlertLogID : AlertLogIDType ; Name1, Name2 : string; Message : string := "" ; Enable : boolean := FALSE ) is
  -- Open files and call AffirmIfDiff[text, ...]
  ------------------------------------------------------------
    variable Valid : boolean ;
  begin
    -- synthesis translate_off
    LocalAlertIfDiff (AlertLogID, Name1, Name2, Message, ERROR, Valid) ;
    if Valid then
      AlertLogStruct.Log(AlertLogID, Message & " " & Name1 & " = " & Name2, PASSED, Enable) ;
    else
      AlertLogStruct.IncAffirmCount(AlertLogID) ;  -- count the affirmation
      -- Alert already signaled by LocalAlertIfDiff
    end if ;
    -- synthesis translate_on
  end procedure AffirmIfDiff ;

  ------------------------------------------------------------
-- DEPRECATED - naming polarity is incorrect.   Should be AffirmIfNotDiff
  procedure AffirmIfDiff (Name1, Name2 : string; Message : string := "" ; Enable : boolean := FALSE ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIfDiff(ALERT_DEFAULT_ID, Name1, Name2, Message, Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfDiff ;

  ------------------------------------------------------------
-- DEPRECATED - naming polarity is incorrect.   Should be AffirmIfNotDiff
  procedure AffirmIfDiff (AlertLogID : AlertLogIDType ; file File1, File2 : text; Message : string := "" ; Enable : boolean := FALSE ) is
  -- Simple diff.
  ------------------------------------------------------------
    variable Valid : boolean ;
  begin
    -- synthesis translate_off
    LocalAlertIfDiff (AlertLogID, File1, File2, Message, ERROR, Valid ) ;
    if Valid then
      AlertLogStruct.Log(AlertLogID, Message, PASSED, Enable) ;
    else
      AlertLogStruct.IncAffirmCount(AlertLogID) ;  -- count the affirmation
      -- Alert already signaled by LocalAlertIfDiff
    end if ;
    -- synthesis translate_on
  end procedure AffirmIfDiff ;

  ------------------------------------------------------------
-- DEPRECATED - naming polarity is incorrect.   Should be AffirmIfNotDiff
  procedure AffirmIfDiff (file File1, File2 : text; Message : string := "" ; Enable : boolean := FALSE ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIfDiff(ALERT_DEFAULT_ID, File1, File2, Message, Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfDiff ;


  -- Support for Specification / Requirements Tracking
  ------------------------------------------------------------
  procedure AffirmIf( RequirementsIDName : string ; condition : boolean ; ReceivedMessage, ExpectedMessage : string ; Enable : boolean := FALSE ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
--?? Set Goal to 1?  Should the ID already exist?
    AffirmIf(GetReqID(RequirementsIDName), condition, ReceivedMessage, ExpectedMessage, Enable) ;
    -- synthesis translate_on
  end procedure AffirmIf ;

  ------------------------------------------------------------
  procedure AffirmIf( RequirementsIDName : string ; condition : boolean ; Message : string ; Enable : boolean := FALSE ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
--?? Set Goal to 1?  Should the ID already exist?
    AffirmIf(GetReqID(RequirementsIDName), condition, Message, Enable) ;
    -- synthesis translate_on
  end procedure AffirmIf ;

  ------------------------------------------------------------
  procedure SetAlertLogJustify (Enable : boolean := TRUE) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.SetJustify(Enable) ;
    -- synthesis translate_on
  end procedure SetAlertLogJustify ;

  ------------------------------------------------------------
  procedure ReportAlerts ( Name : String ; AlertCount : AlertCountType ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.ReportAlerts(Name, AlertCount) ;
    -- synthesis translate_on
  end procedure ReportAlerts ;

  ------------------------------------------------------------
  procedure ReportRequirements is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.ReportRequirements ;
    -- synthesis translate_on
  end procedure ReportRequirements ;

  ------------------------------------------------------------
  procedure ReportAlerts (
  ------------------------------------------------------------
    Name           : string          := OSVVM_STRING_INIT_PARM_DETECT ;
    AlertLogID     : AlertLogIDType  := ALERTLOG_BASE_ID ;
    ExternalErrors : AlertCountType  := (others => 0) ;
    ReportAll      : Boolean         := FALSE
  ) is
  begin
    -- synthesis translate_off
    AlertLogStruct.ReportAlerts(Name, AlertLogID, ExternalErrors, ReportAll, TRUE) ;
    -- synthesis translate_on
  end procedure ReportAlerts ;

  ------------------------------------------------------------
  procedure ReportNonZeroAlerts (
  ------------------------------------------------------------
    Name           : string          := OSVVM_STRING_INIT_PARM_DETECT ;
    AlertLogID     : AlertLogIDType  := ALERTLOG_BASE_ID ;
    ExternalErrors : AlertCountType  := (others => 0)
  ) is
  begin
    -- synthesis translate_off
    AlertLogStruct.ReportAlerts(Name, AlertLogID, ExternalErrors, FALSE, FALSE) ;
    -- synthesis translate_on
  end procedure ReportNonZeroAlerts ;

  ------------------------------------------------------------
  procedure WriteAlertYaml (
  ------------------------------------------------------------
    FileName       : string ;
    ExternalErrors : AlertCountType := (0,0,0) ;
    Prefix         : string := "" ;
    PrintSettings  : boolean := TRUE ;
    PrintChildren  : boolean := TRUE ;
    OpenKind       : File_Open_Kind := WRITE_MODE
  ) is
  begin
    -- synthesis translate_off
    AlertLogStruct.WriteAlertYaml(FileName, ExternalErrors, Prefix, PrintSettings, PrintChildren, OpenKind) ;
    -- synthesis translate_on
  end procedure WriteAlertYaml ;

  ------------------------------------------------------------
  procedure WriteAlertSummaryYaml (FileName : string := "" ; ExternalErrors : AlertCountType := (0,0,0)) is
  ------------------------------------------------------------
    constant RESOLVED_FILE_NAME : string := IfElse(FileName'length = 0, OSVVM_BUILD_YAML_FILE, FileName) ;
  begin
    -- synthesis translate_off
    WriteAlertYaml(FileName => RESOLVED_FILE_NAME, ExternalErrors => ExternalErrors, Prefix => "        ", PrintSettings => FALSE, PrintChildren => FALSE, OpenKind => APPEND_MODE) ;
    -- WriteTestSummary(FileName => OSVVM_BUILD_YAML_FILE, OpenKind => APPEND_MODE, Prefix => "      ", Suffix => "", ExternalErrors => ExternalErrors, WriteFieldName => TRUE) ;
    -- synthesis translate_on
  end procedure WriteAlertSummaryYaml ;

  ------------------------------------------------------------
  -- Deprecated.  Use WriteAlertSummaryYaml Instead.
  procedure CreateYamlReport (ExternalErrors : AlertCountType := (0,0,0)) is
  begin
    -- synthesis translate_off
    WriteAlertSummaryYaml(ExternalErrors => ExternalErrors) ;
    -- synthesis translate_on
  end procedure CreateYamlReport ;

  ------------------------------------------------------------
  procedure WriteTestSummary (
  ------------------------------------------------------------
    FileName       : string ;
    OpenKind       : File_Open_Kind := APPEND_MODE ;
    Prefix         : string := "" ;
    Suffix         : string := "" ;
    ExternalErrors : AlertCountType := (0,0,0) ;
    WriteFieldName : boolean := FALSE
  ) is
  begin
    -- synthesis translate_off
    AlertLogStruct.WriteTestSummary(FileName, OpenKind, Prefix, Suffix, ExternalErrors, WriteFieldName) ;
    -- synthesis translate_on
  end procedure WriteTestSummary ;

  ------------------------------------------------------------
  procedure WriteTestSummaries (
  ------------------------------------------------------------
    FileName    : string ;
    OpenKind    : File_Open_Kind := WRITE_MODE
  ) is
  begin
    -- synthesis translate_off
    AlertLogStruct.WriteTestSummaries(FileName, OpenKind) ;
    -- synthesis translate_on
  end procedure WriteTestSummaries ;

  ------------------------------------------------------------
  procedure ReportTestSummaries is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.ReportTestSummaries ;
    -- synthesis translate_on
  end procedure ReportTestSummaries ;

  ------------------------------------------------------------
  procedure WriteAlerts (
  ------------------------------------------------------------
    FileName    : string ;
    AlertLogID  : AlertLogIDType := ALERTLOG_BASE_ID ;
    OpenKind    : File_Open_Kind := WRITE_MODE
  ) is
  begin
    -- synthesis translate_off
    AlertLogStruct.WriteAlerts(FileName, AlertLogID, OpenKind) ;
    -- synthesis translate_on
  end procedure WriteAlerts ;

  ------------------------------------------------------------
  procedure WriteRequirements (
  ------------------------------------------------------------
    FileName        : string ;
    AlertLogID      : AlertLogIDType := REQUIREMENT_ALERTLOG_ID ;
    OpenKind        : File_Open_Kind := WRITE_MODE
  ) is
  begin
    -- synthesis translate_off
    AlertLogStruct.WriteRequirements(FileName, AlertLogID, OpenKind) ;
    -- synthesis translate_on
  end procedure WriteRequirements ;

  ------------------------------------------------------------
  procedure ReadSpecification (FileName : string ; PassedGoal : integer := -1 ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.ReadSpecification(FileName, PassedGoal) ;
    -- synthesis translate_on
  end procedure ReadSpecification ;

  ------------------------------------------------------------
  procedure ReadRequirements (
  ------------------------------------------------------------
    FileName        : string ;
    ThresholdPassed : boolean := FALSE
  ) is
  begin
    -- synthesis translate_off
    AlertLogStruct.ReadRequirements(FileName, ThresholdPassed, TestSummary => FALSE) ;
    -- synthesis translate_on
  end procedure ReadRequirements ;

  ------------------------------------------------------------
  procedure ReadTestSummaries (FileName : string) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.ReadRequirements(FileName, ThresholdPassed => FALSE, TestSummary => TRUE) ;
    -- synthesis translate_on
  end procedure ReadTestSummaries ;

--  ------------------------------------------------------------
--  procedure ReportTestSummaries (FileName : string) is
--  ------------------------------------------------------------
--  begin
--    -- synthesis translate_off
--    AlertLogStruct.ReadRequirements(FileName, ThresholdPassed => FALSE, TestSummary => TRUE) ;
--    -- synthesis translate_on
--  end procedure ReportTestSummaries ;

  ------------------------------------------------------------
  procedure ClearAlerts is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.ClearAlerts ;
    -- synthesis translate_on
  end procedure ClearAlerts ;

  ------------------------------------------------------------
  procedure ClearAlertStopCounts is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.ClearAlertStopCounts ;
    -- synthesis translate_on
  end procedure ClearAlertStopCounts ;

  ------------------------------------------------------------
  procedure ClearAlertCounts is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.ClearAlerts ;
    AlertLogStruct.ClearAlertStopCounts ;
    -- synthesis translate_on
  end procedure ClearAlertCounts ;

  ------------------------------------------------------------
  function "ABS" (L : AlertCountType) return AlertCountType is
  ------------------------------------------------------------
    variable Result : AlertCountType ;
  begin
    -- synthesis translate_off
    Result(FAILURE) := ABS( L(FAILURE) ) ;
    Result(ERROR)   := ABS( L(ERROR) ) ;
    Result(WARNING) := ABS( L(WARNING) );
    -- synthesis translate_on
    return Result ;
  end function "ABS" ;

  ------------------------------------------------------------
  function "+" (L, R : AlertCountType) return AlertCountType is
  ------------------------------------------------------------
    variable Result : AlertCountType ;
  begin
    -- synthesis translate_off
    Result(FAILURE) := L(FAILURE) + R(FAILURE) ;
    Result(ERROR)   := L(ERROR)   + R(ERROR) ;
    Result(WARNING) := L(WARNING) + R(WARNING) ;
    -- synthesis translate_on
    return Result ;
  end function "+" ;

  ------------------------------------------------------------
  function "-" (L, R : AlertCountType) return AlertCountType is
  ------------------------------------------------------------
    variable Result : AlertCountType ;
  begin
    -- synthesis translate_off
    Result(FAILURE) := L(FAILURE) - R(FAILURE) ;
    Result(ERROR)   := L(ERROR)   - R(ERROR) ;
    Result(WARNING) := L(WARNING) - R(WARNING) ;
    -- synthesis translate_on
    return Result ;
  end function "-" ;

  ------------------------------------------------------------
  function "-" (R : AlertCountType) return AlertCountType is
  ------------------------------------------------------------
    variable Result : AlertCountType ;
  begin
    -- synthesis translate_off
    Result(FAILURE) := - R(FAILURE) ;
    Result(ERROR)   := - R(ERROR) ;
    Result(WARNING) := - R(WARNING) ;
    -- synthesis translate_on
    return Result ;
  end function "-" ;

  ------------------------------------------------------------
  impure function SumAlertCount(AlertCount: AlertCountType) return integer is
  ------------------------------------------------------------
    variable result : integer ;
  begin
    -- synthesis translate_off
    -- Using ABS ensures correct expected error handling.
    result := abs(AlertCount(FAILURE)) + abs(AlertCount(ERROR)) + abs(AlertCount(WARNING)) ;
    -- synthesis translate_on
    return result ;
  end function SumAlertCount ;

  ------------------------------------------------------------
  impure function GetAlertCount(AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID) return AlertCountType is
  ------------------------------------------------------------
    variable result : AlertCountType ;
  begin
    -- synthesis translate_off
    result := AlertLogStruct.GetAlertCount(AlertLogID) ;
    -- synthesis translate_on
    return result ;
  end function GetAlertCount ;

  ------------------------------------------------------------
  impure function GetAlertCount(AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID) return integer is
  ------------------------------------------------------------
    variable result : integer ;
  begin
    -- synthesis translate_off
    result := SumAlertCount(AlertLogStruct.GetAlertCount(AlertLogID)) ;
    -- synthesis translate_on
    return result ;
  end function GetAlertCount ;

  ------------------------------------------------------------
  impure function GetEnabledAlertCount(AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID) return AlertCountType is
  ------------------------------------------------------------
    variable result : AlertCountType ;
  begin
    -- synthesis translate_off
    result := AlertLogStruct.GetEnabledAlertCount(AlertLogID) ;
    -- synthesis translate_on
    return result ;
  end function GetEnabledAlertCount ;

  ------------------------------------------------------------
  impure function GetEnabledAlertCount(AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID) return integer is
  ------------------------------------------------------------
    variable result : integer ;
  begin
    -- synthesis translate_off
    result := SumAlertCount(AlertLogStruct.GetEnabledAlertCount(AlertLogID)) ;
    -- synthesis translate_on
    return result ;
  end function GetEnabledAlertCount ;

  ------------------------------------------------------------
  impure function GetDisabledAlertCount return AlertCountType is
  ------------------------------------------------------------
    variable result : AlertCountType ;
  begin
    -- synthesis translate_off
    result := AlertLogStruct.GetDisabledAlertCount ;
    -- synthesis translate_on
    return result ;
  end function GetDisabledAlertCount ;

  ------------------------------------------------------------
  impure function GetDisabledAlertCount return integer is
  ------------------------------------------------------------
    variable result : integer ;
  begin
    -- synthesis translate_off
    result := SumAlertCount(AlertLogStruct.GetDisabledAlertCount) ;
    -- synthesis translate_on
    return result ;
  end function GetDisabledAlertCount ;

  ------------------------------------------------------------
  impure function GetDisabledAlertCount(AlertLogID: AlertLogIDType) return AlertCountType is
  ------------------------------------------------------------
    variable result : AlertCountType ;
  begin
    -- synthesis translate_off
    result := AlertLogStruct.GetDisabledAlertCount(AlertLogID) ;
    -- synthesis translate_on
    return result ;
  end function GetDisabledAlertCount ;

  ------------------------------------------------------------
  impure function GetDisabledAlertCount(AlertLogID: AlertLogIDType) return integer is
  ------------------------------------------------------------
    variable result : integer ;
  begin
    -- synthesis translate_off
    result := SumAlertCount(AlertLogStruct.GetDisabledAlertCount(AlertLogID)) ;
    -- synthesis translate_on
    return result ;
  end function GetDisabledAlertCount ;

  ------------------------------------------------------------
  procedure Log(
  ------------------------------------------------------------
    AlertLogID   : AlertLogIDType ;
    Message      : string ;
    Level        : LogType := ALWAYS ;
    Enable       : boolean := FALSE    -- override internal enable
  ) is
  begin
    -- synthesis translate_off
    AlertLogStruct.Log(AlertLogID, Message, Level, Enable) ;
    -- synthesis translate_on
  end procedure log ;

  ------------------------------------------------------------
  procedure Log( Message : string ; Level : LogType := ALWAYS ; Enable : boolean := FALSE) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.Log(LOG_DEFAULT_ID, Message, Level, Enable) ;
    -- synthesis translate_on
  end procedure log ;

  ------------------------------------------------------------
  procedure SetAlertEnable(Level : AlertType ;  Enable : boolean) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.SetAlertEnable(Level, Enable) ;
    -- synthesis translate_on
  end procedure SetAlertEnable ;

  ------------------------------------------------------------
  procedure SetAlertEnable(AlertLogID : AlertLogIDType ;  Level : AlertType ;  Enable : boolean ; DescendHierarchy : boolean := TRUE) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.SetAlertEnable(AlertLogID, Level, Enable, DescendHierarchy) ;
    -- synthesis translate_on
  end procedure SetAlertEnable ;

  ------------------------------------------------------------
  impure function GetAlertEnable(AlertLogID : AlertLogIDType ;  Level : AlertType) return boolean is
  ------------------------------------------------------------
    variable result : boolean ;
  begin
    -- synthesis translate_off
    result := AlertLogStruct.GetAlertEnable(AlertLogID, Level) ;
    -- synthesis translate_on
    return result ;
  end function GetAlertEnable ;

  ------------------------------------------------------------
  impure function GetAlertEnable(Level : AlertType) return boolean is
  ------------------------------------------------------------
    variable result : boolean ;
  begin
    -- synthesis translate_off
    result := AlertLogStruct.GetAlertEnable(ALERT_DEFAULT_ID, Level) ;
    -- synthesis translate_on
    return result ;
  end function GetAlertEnable ;

  ------------------------------------------------------------
  procedure SetLogEnable(Level : LogType ;  Enable : boolean) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.SetLogEnable(Level, Enable) ;
    -- synthesis translate_on
  end procedure SetLogEnable ;

  ------------------------------------------------------------
  procedure SetLogEnable(AlertLogID : AlertLogIDType ;  Level : LogType ;  Enable : boolean ; DescendHierarchy : boolean := TRUE) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.SetLogEnable(AlertLogID, Level, Enable, DescendHierarchy) ;
    -- synthesis translate_on
  end procedure SetLogEnable ;

  ------------------------------------------------------------
  impure function GetLogEnable(AlertLogID : AlertLogIDType ;  Level : LogType) return boolean is
  ------------------------------------------------------------
    variable result : boolean ;
  begin
    -- synthesis translate_off
    result := AlertLogStruct.GetLogEnable(AlertLogID, Level) ;
    -- synthesis translate_on
    return result ;
  end function GetLogEnable ;

  ------------------------------------------------------------
  impure function GetLogEnable(Level : LogType) return boolean is
  ------------------------------------------------------------
    variable result : boolean ;
  begin
    -- synthesis translate_off
    result := AlertLogStruct.GetLogEnable(LOG_DEFAULT_ID, Level) ;
    -- synthesis translate_on
    return result ;
  end function GetLogEnable ;

  ------------------------------------------------------------
  procedure ReportLogEnables is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.ReportLogEnables ;
    -- synthesis translate_on
  end ReportLogEnables ;

 ------------------------------------------------------------
  procedure SetTestName(Name : string ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.SetTestName(Name) ;
    -- synthesis translate_on
  end procedure SetTestName ;

  -- synthesis translate_off
  ------------------------------------------------------------
  impure function GetTestName return string is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogName(ALERTLOG_BASE_ID) ;
  end function GetTestName ;

  ------------------------------------------------------------
  impure function GetTranscriptName return string is
  ------------------------------------------------------------
  begin
    return GetTestName & ".log" ;
  end function GetTranscriptName ;

  ------------------------------------------------------------
  impure function GetAlertLogName(AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID) return string is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogName(AlertLogID) ;
  end GetAlertLogName ;
  -- synthesis translate_on

  ------------------------------------------------------------
  procedure DeallocateAlertLogStruct is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.DeallocateAlertLogStruct ;
    -- synthesis translate_on
  end procedure DeallocateAlertLogStruct ;

  ------------------------------------------------------------
  procedure InitializeAlertLogStruct is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.Initialize ;
    -- synthesis translate_on
  end procedure InitializeAlertLogStruct ;

  ------------------------------------------------------------
  impure function FindAlertLogID(Name : string ) return AlertLogIDType is
  ------------------------------------------------------------
    variable result : AlertLogIDType ;
  begin
    -- synthesis translate_off
    result := AlertLogStruct.FindAlertLogID(Name) ;
    -- synthesis translate_on
    return result ;
  end function FindAlertLogID ;

  ------------------------------------------------------------
  impure function FindAlertLogID(Name : string ; ParentID : AlertLogIDType) return AlertLogIDType is
  ------------------------------------------------------------
    variable result : AlertLogIDType ;
  begin
    -- synthesis translate_off
    result := AlertLogStruct.FindAlertLogID(Name, ParentID) ;
    -- synthesis translate_on
    return result ;
  end function FindAlertLogID ;

  ------------------------------------------------------------
  impure function NewID(
  ------------------------------------------------------------
    Name            : string ;
    ParentID        : AlertLogIDType          := ALERTLOG_ID_NOT_ASSIGNED;
    ReportMode      : AlertLogReportModeType  := ENABLED ;
    PrintParent     : AlertLogPrintParentType := PRINT_NAME_AND_PARENT ;
    CreateHierarchy : boolean                 := TRUE
  ) return AlertLogIDType is
    variable result : AlertLogIDType ;
	begin
    -- synthesis translate_off
    result := AlertLogStruct.NewID(Name, ParentID, ReportMode, PrintParent, CreateHierarchy) ;
    -- synthesis translate_on
    return result ;
  end function NewID ;

  ------------------------------------------------------------
  impure function GetAlertLogID(Name : string; ParentID : AlertLogIDType := ALERTLOG_ID_NOT_ASSIGNED; CreateHierarchy : Boolean := TRUE; DoNotReport : Boolean := FALSE) return AlertLogIDType is
  ------------------------------------------------------------
    variable result : AlertLogIDType ;
		variable ReportMode  : AlertLogReportModeType := ENABLED ;
	begin
    -- synthesis translate_off
    if DoNotReport then
        ReportMode := DISABLED ;
    end if;
    -- PrintParent PRINT_NAME_AND_PARENT is not backward compatible with PRINT_NAME of the past
    result := AlertLogStruct.NewID(Name, ParentID, ReportMode => ReportMode, PrintParent => PRINT_NAME, CreateHierarchy => CreateHierarchy) ;
--    result := AlertLogStruct.GetAlertLogID(Name, ParentID, CreateHierarchy, DoNotReport) ;
    -- synthesis translate_on
    return result ;
  end function GetAlertLogID ;

  ------------------------------------------------------------
  impure function GetReqID(Name : string ; PassedGoal : integer := -1 ; ParentID : AlertLogIDType := ALERTLOG_ID_NOT_ASSIGNED ; CreateHierarchy : Boolean := TRUE) return AlertLogIDType is
  ------------------------------------------------------------
    variable result : AlertLogIDType ;
  begin
    -- synthesis translate_off
    result := AlertLogStruct.GetReqID(Name, PassedGoal, ParentID, CreateHierarchy) ;
    -- synthesis translate_on
    return result ;
  end function GetReqID ;

  ------------------------------------------------------------
  procedure SetPassedGoal(AlertLogID : AlertLogIDType ; PassedGoal : integer ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.SetPassedGoal(AlertLogID, PassedGoal) ;
    -- synthesis translate_on
  end procedure SetPassedGoal ;

  ------------------------------------------------------------
  impure function GetAlertLogParentID(AlertLogID : AlertLogIDType) return AlertLogIDType is
  ------------------------------------------------------------
    variable result : AlertLogIDType ;
  begin
    -- synthesis translate_off
    result := AlertLogStruct.GetAlertLogParentID(AlertLogID) ;
    -- synthesis translate_on
    return result ;
  end function GetAlertLogParentID ;

  ------------------------------------------------------------
  procedure SetAlertLogPrefix(AlertLogID : AlertLogIDType; Name : string ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.SetAlertLogPrefix(AlertLogID, Name) ;
    -- synthesis translate_on
  end procedure SetAlertLogPrefix ;

  ------------------------------------------------------------
  procedure UnSetAlertLogPrefix(AlertLogID : AlertLogIDType ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.UnSetAlertLogPrefix(AlertLogID) ;
    -- synthesis translate_on
  end procedure UnSetAlertLogPrefix ;

  -- synthesis translate_off
  ------------------------------------------------------------
  impure function GetAlertLogPrefix(AlertLogID : AlertLogIDType) return string is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogPrefix(AlertLogID) ;
  end function GetAlertLogPrefix ;
  -- synthesis translate_on

  ------------------------------------------------------------
  procedure SetAlertLogSuffix(AlertLogID : AlertLogIDType; Name : string ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.SetAlertLogSuffix(AlertLogID, Name) ;
    -- synthesis translate_on
  end procedure SetAlertLogSuffix ;

  ------------------------------------------------------------
  procedure UnSetAlertLogSuffix(AlertLogID : AlertLogIDType ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.UnSetAlertLogSuffix(AlertLogID) ;
    -- synthesis translate_on
  end procedure UnSetAlertLogSuffix ;

  -- synthesis translate_off
  ------------------------------------------------------------
  impure function GetAlertLogSuffix(AlertLogID : AlertLogIDType) return string is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogSuffix(AlertLogID) ;
  end function GetAlertLogSuffix ;
  -- synthesis translate_on

  ------------------------------------------------------------
  procedure SetGlobalAlertEnable (A : boolean := TRUE) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.SetGlobalAlertEnable(A) ;
    -- synthesis translate_on
  end procedure SetGlobalAlertEnable ;

  ------------------------------------------------------------
  -- Set using constant.  Set before code runs.
  impure function SetGlobalAlertEnable (A : boolean := TRUE) return boolean is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.SetGlobalAlertEnable(A) ;
    -- synthesis translate_on
    return A ;
  end function SetGlobalAlertEnable ;

  ------------------------------------------------------------
  impure function GetGlobalAlertEnable return boolean is
  ------------------------------------------------------------
    variable result : boolean ;
  begin
    -- synthesis translate_off
    result := AlertLogStruct.GetGlobalAlertEnable ;
    -- synthesis translate_on
    return result ;
  end function GetGlobalAlertEnable ;

  ------------------------------------------------------------
  procedure IncAffirmCount(AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.IncAffirmCount(AlertLogID) ;
    -- synthesis translate_on
  end procedure IncAffirmCount ;

  ------------------------------------------------------------
  impure function GetAffirmCount return natural is
  ------------------------------------------------------------
    variable result : natural ;
  begin
    -- synthesis translate_off
    result := AlertLogStruct.GetAffirmCount ;
    -- synthesis translate_on
    return result ;
  end function GetAffirmCount ;

  ------------------------------------------------------------
  procedure IncAffirmPassedCount(AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.IncAffirmPassedCount(AlertLogID) ;
    -- synthesis translate_on
  end procedure IncAffirmPassedCount ;

  ------------------------------------------------------------
  impure function GetAffirmPassedCount return natural is
  ------------------------------------------------------------
    variable result : natural ;
  begin
    -- synthesis translate_off
    result := AlertLogStruct.GetAffirmPassedCount ;
    -- synthesis translate_on
    return result ;
  end function GetAffirmPassedCount ;

  ------------------------------------------------------------
  procedure SetAlertStopCount(AlertLogID : AlertLogIDType ;  Level : AlertType ;  Count : integer) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.SetAlertStopCount(AlertLogID, Level, Count) ;
    -- synthesis translate_on
  end procedure SetAlertStopCount ;

  ------------------------------------------------------------
  procedure SetAlertStopCount(Level : AlertType ;  Count : integer) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.SetAlertStopCount(ALERTLOG_BASE_ID, Level, Count) ;
    -- synthesis translate_on
  end procedure SetAlertStopCount ;

  ------------------------------------------------------------
  impure function GetAlertStopCount(AlertLogID : AlertLogIDType ;  Level : AlertType) return integer is
  ------------------------------------------------------------
    variable result : integer ;
  begin
    -- synthesis translate_off
    result := AlertLogStruct.GetAlertStopCount(AlertLogID, Level) ;
    -- synthesis translate_on
    return result ;
  end function GetAlertStopCount ;

  ------------------------------------------------------------
  impure function GetAlertStopCount(Level : AlertType) return integer is
  ------------------------------------------------------------
    variable result : integer ;
  begin
    -- synthesis translate_off
    result := AlertLogStruct.GetAlertStopCount(ALERTLOG_BASE_ID, Level) ;
    -- synthesis translate_on
    return result ;
  end function GetAlertStopCount ;

  ------------------------------------------------------------
  procedure SetAlertPrintCount(AlertLogID : AlertLogIDType ;  Level : AlertType ;  Count : integer) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.SetAlertPrintCount(AlertLogID, Level, Count) ;
    -- synthesis translate_on
  end procedure SetAlertPrintCount ;

  ------------------------------------------------------------
  procedure SetAlertPrintCount(Level : AlertType ;  Count : integer) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.SetAlertPrintCount(ALERTLOG_DEFAULT_ID, Level, Count) ;
    -- synthesis translate_on
  end procedure SetAlertPrintCount ;

  ------------------------------------------------------------
  impure function GetAlertPrintCount(AlertLogID : AlertLogIDType ;  Level : AlertType) return integer is
  ------------------------------------------------------------
    variable result : integer ;
  begin
    -- synthesis translate_off
    result := AlertLogStruct.GetAlertPrintCount(AlertLogID, Level) ;
    -- synthesis translate_on
    return result ;
  end function GetAlertPrintCount ;

  ------------------------------------------------------------
  impure function GetAlertPrintCount(Level : AlertType) return integer is
  ------------------------------------------------------------
    variable result : integer ;
  begin
    -- synthesis translate_off
    result := AlertLogStruct.GetAlertPrintCount(ALERTLOG_DEFAULT_ID, Level) ;
    -- synthesis translate_on
    return result ;
  end function GetAlertPrintCount ;

  ------------------------------------------------------------
  procedure SetAlertPrintCount(AlertLogID : AlertLogIDType ;  Count : AlertCountType) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.SetAlertPrintCount(AlertLogID, Count) ;
    -- synthesis translate_on
  end procedure SetAlertPrintCount ;

  ------------------------------------------------------------
  procedure SetAlertPrintCount(Count : AlertCountType) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.SetAlertPrintCount(ALERTLOG_DEFAULT_ID, Count) ;
    -- synthesis translate_on
  end procedure SetAlertPrintCount ;

  ------------------------------------------------------------
  impure function GetAlertPrintCount(AlertLogID : AlertLogIDType) return AlertCountType is
  ------------------------------------------------------------
    variable result : AlertCountType ;
  begin
    -- synthesis translate_off
    result := AlertLogStruct.GetAlertPrintCount(AlertLogID) ;
    -- synthesis translate_on
    return result ;
  end function GetAlertPrintCount ;

  ------------------------------------------------------------
  impure function GetAlertPrintCount return AlertCountType is
  ------------------------------------------------------------
    variable result : AlertCountType ;
  begin
    -- synthesis translate_off
    result := AlertLogStruct.GetAlertPrintCount(ALERTLOG_DEFAULT_ID) ;
    -- synthesis translate_on
    return result ;
  end function GetAlertPrintCount ;

  ------------------------------------------------------------
  procedure SetAlertLogPrintParent(AlertLogID : AlertLogIDType ;  PrintParent : AlertLogPrintParentType) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.SetAlertLogPrintParent(AlertLogID, PrintParent) ;
    -- synthesis translate_on
  end procedure SetAlertLogPrintParent ;

  ------------------------------------------------------------
  procedure SetAlertLogPrintParent(                                PrintParent : AlertLogPrintParentType) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.SetAlertLogPrintParent(ALERTLOG_DEFAULT_ID, PrintParent) ;
    -- synthesis translate_on
  end procedure SetAlertLogPrintParent ;

  ------------------------------------------------------------
  impure function GetAlertLogPrintParent(AlertLogID : AlertLogIDType) return AlertLogPrintParentType is
  ------------------------------------------------------------
    variable result : AlertLogPrintParentType ;
  begin
    -- synthesis translate_off
    result := AlertLogStruct.GetAlertLogPrintParent(AlertLogID) ;
    -- synthesis translate_on
    return result ;
  end function GetAlertLogPrintParent ;

  ------------------------------------------------------------
  impure function GetAlertLogPrintParent                              return AlertLogPrintParentType is
  ------------------------------------------------------------
    variable result : AlertLogPrintParentType ;
  begin
    -- synthesis translate_off
    result := AlertLogStruct.GetAlertLogPrintParent(ALERTLOG_DEFAULT_ID) ;
    -- synthesis translate_on
    return result ;
  end function GetAlertLogPrintParent ;

  ------------------------------------------------------------
  procedure SetAlertLogReportMode(AlertLogID : AlertLogIDType ;  ReportMode : AlertLogReportModeType) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.SetAlertLogReportMode(AlertLogID, ReportMode) ;
    -- synthesis translate_on
  end procedure SetAlertLogReportMode ;

  ------------------------------------------------------------
  procedure SetAlertLogReportMode(                                ReportMode : AlertLogReportModeType) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.SetAlertLogReportMode(ALERTLOG_DEFAULT_ID, ReportMode) ;
    -- synthesis translate_on
  end procedure SetAlertLogReportMode ;

  ------------------------------------------------------------
  impure function GetAlertLogReportMode(AlertLogID : AlertLogIDType) return AlertLogReportModeType is
  ------------------------------------------------------------
    variable result : AlertLogReportModeType ;
  begin
    -- synthesis translate_off
    result := AlertLogStruct.GetAlertLogReportMode(AlertLogID) ;
    -- synthesis translate_on
    return result ;
  end function GetAlertLogReportMode ;

  ------------------------------------------------------------
  impure function GetAlertLogReportMode                              return AlertLogReportModeType is
  ------------------------------------------------------------
    variable result : AlertLogReportModeType ;
  begin
    -- synthesis translate_off
    result := AlertLogStruct.GetAlertLogReportMode(ALERTLOG_DEFAULT_ID) ;
    -- synthesis translate_on
    return result ;
  end function GetAlertLogReportMode ;

  ------------------------------------------------------------
  procedure SetAlertLogOptions (
  ------------------------------------------------------------
    FailOnWarning            : OsvvmOptionsType := OPT_INIT_PARM_DETECT ;
    FailOnDisabledErrors     : OsvvmOptionsType := OPT_INIT_PARM_DETECT ;
    FailOnRequirementErrors  : OsvvmOptionsType := OPT_INIT_PARM_DETECT ;
    ReportHierarchy          : OsvvmOptionsType := OPT_INIT_PARM_DETECT ;
    WriteAlertErrorCount     : OsvvmOptionsType := OPT_INIT_PARM_DETECT ;
    WriteAlertLevel          : OsvvmOptionsType := OPT_INIT_PARM_DETECT ;
    WriteAlertName           : OsvvmOptionsType := OPT_INIT_PARM_DETECT ;
    WriteAlertTime           : OsvvmOptionsType := OPT_INIT_PARM_DETECT ;
    WriteLogErrorCount       : OsvvmOptionsType := OPT_INIT_PARM_DETECT ;
    WriteLogLevel            : OsvvmOptionsType := OPT_INIT_PARM_DETECT ;
    WriteLogName             : OsvvmOptionsType := OPT_INIT_PARM_DETECT ;
    WriteLogTime             : OsvvmOptionsType := OPT_INIT_PARM_DETECT ;
    PrintPassed              : OsvvmOptionsType := OPT_INIT_PARM_DETECT ;
    PrintAffirmations        : OsvvmOptionsType := OPT_INIT_PARM_DETECT ;
    PrintDisabledAlerts      : OsvvmOptionsType := OPT_INIT_PARM_DETECT ;
    PrintRequirements        : OsvvmOptionsType := OPT_INIT_PARM_DETECT ;
    PrintIfHaveRequirements  : OsvvmOptionsType := OPT_INIT_PARM_DETECT ;
    DefaultPassedGoal        : integer          := integer'left ;
    AlertPrefix              : string := OSVVM_STRING_INIT_PARM_DETECT ;
    LogPrefix                : string := OSVVM_STRING_INIT_PARM_DETECT ;
    ReportPrefix             : string := OSVVM_STRING_INIT_PARM_DETECT ;
    DoneName                 : string := OSVVM_STRING_INIT_PARM_DETECT ;
    PassName                 : string := OSVVM_STRING_INIT_PARM_DETECT ;
    FailName                 : string := OSVVM_STRING_INIT_PARM_DETECT ;
    IdSeparator              : string := OSVVM_STRING_INIT_PARM_DETECT ;
    WriteTimeLast            : OsvvmOptionsType := OPT_INIT_PARM_DETECT ;
    TimeJustifyAmount        : integer          := integer'left 
  ) is
  begin
    -- synthesis translate_off
    AlertLogStruct.SetAlertLogOptions (
      FailOnWarning            => FailOnWarning,
      FailOnDisabledErrors     => FailOnDisabledErrors,
      FailOnRequirementErrors  => FailOnRequirementErrors,
      ReportHierarchy          => ReportHierarchy,
      WriteAlertErrorCount     => WriteAlertErrorCount,
      WriteAlertLevel          => WriteAlertLevel,
      WriteAlertName           => WriteAlertName,
      WriteAlertTime           => WriteAlertTime,
      WriteLogErrorCount       => WriteLogErrorCount,
      WriteLogLevel            => WriteLogLevel,
      WriteLogName             => WriteLogName,
      WriteLogTime             => WriteLogTime,
      PrintPassed              => PrintPassed,
      PrintAffirmations        => PrintAffirmations,
      PrintDisabledAlerts      => PrintDisabledAlerts,
      PrintRequirements        => PrintRequirements,
      PrintIfHaveRequirements  => PrintIfHaveRequirements,
      DefaultPassedGoal        => DefaultPassedGoal,
      AlertPrefix              => AlertPrefix,
      LogPrefix                => LogPrefix,
      ReportPrefix             => ReportPrefix,
      DoneName                 => DoneName,
      PassName                 => PassName,
      FailName                 => FailName,
      IdSeparator              => IdSeparator,
      WriteTimeLast            => WriteTimeLast, 
      TimeJustifyAmount        => TimeJustifyAmount 
    );
    -- synthesis translate_on
  end procedure SetAlertLogOptions ;

  ------------------------------------------------------------
  procedure ReportAlertLogOptions is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.ReportAlertLogOptions ;
    -- synthesis translate_on
  end procedure ReportAlertLogOptions ;



  -- synthesis translate_off

  ------------------------------------------------------------
  impure function GetAlertLogFailOnWarning        return OsvvmOptionsType is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogFailOnWarning ;
  end function GetAlertLogFailOnWarning ;

  ------------------------------------------------------------
  impure function GetAlertLogFailOnDisabledErrors return OsvvmOptionsType is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogFailOnDisabledErrors ;
  end function GetAlertLogFailOnDisabledErrors ;

  ------------------------------------------------------------
  impure function GetAlertLogFailOnRequirementErrors return OsvvmOptionsType is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogFailOnRequirementErrors ;
  end function GetAlertLogFailOnRequirementErrors ;

  ------------------------------------------------------------
  impure function GetAlertLogReportHierarchy      return OsvvmOptionsType is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogReportHierarchy ;
  end function GetAlertLogReportHierarchy ;

  ------------------------------------------------------------
  impure function GetAlertLogFoundReportHier       return boolean is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogFoundReportHier ;
  end function GetAlertLogFoundReportHier ;

  ------------------------------------------------------------
  impure function GetAlertLogFoundAlertHier       return boolean is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogFoundAlertHier ;
  end function GetAlertLogFoundAlertHier ;

  ------------------------------------------------------------
  impure function GetAlertLogWriteAlertErrorCount return OsvvmOptionsType is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogWriteAlertErrorCount ;
  end function GetAlertLogWriteAlertErrorCount ;

  ------------------------------------------------------------
  impure function GetAlertLogWriteAlertLevel      return OsvvmOptionsType is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogWriteAlertLevel ;
  end function GetAlertLogWriteAlertLevel ;

  ------------------------------------------------------------
  impure function GetAlertLogWriteAlertName       return OsvvmOptionsType is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogWriteAlertName ;
  end function GetAlertLogWriteAlertName ;

  ------------------------------------------------------------
  impure function GetAlertLogWriteAlertTime       return OsvvmOptionsType is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogWriteAlertTime ;
  end function GetAlertLogWriteAlertTime ;

  ------------------------------------------------------------
  impure function GetAlertLogWriteLogErrorCount return OsvvmOptionsType is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogWriteLogErrorCount ;
  end function GetAlertLogWriteLogErrorCount ;

  ------------------------------------------------------------
  impure function GetAlertLogWriteLogLevel        return OsvvmOptionsType is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogWriteLogLevel ;
  end function GetAlertLogWriteLogLevel ;

  ------------------------------------------------------------
  impure function GetAlertLogWriteLogName         return OsvvmOptionsType is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogWriteLogName ;
  end function GetAlertLogWriteLogName ;

  ------------------------------------------------------------
  impure function GetAlertLogWriteLogTime         return OsvvmOptionsType is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogWriteLogTime ;
  end function GetAlertLogWriteLogTime ;

  ------------------------------------------------------------
  impure function GetAlertLogPrintPassed    return OsvvmOptionsType is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogPrintPassed ;
  end function GetAlertLogPrintPassed ;

  ------------------------------------------------------------
  impure function GetAlertLogPrintAffirmations    return OsvvmOptionsType is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogPrintAffirmations ;
  end function GetAlertLogPrintAffirmations ;

  ------------------------------------------------------------
  impure function GetAlertLogPrintDisabledAlerts  return OsvvmOptionsType is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogPrintDisabledAlerts ;
  end function GetAlertLogPrintDisabledAlerts ;

  ------------------------------------------------------------
  impure function GetAlertLogPrintRequirements    return OsvvmOptionsType is
  ------------------------------------------------------------
  begin
  return AlertLogStruct.GetAlertLogPrintRequirements ;
  end function GetAlertLogPrintRequirements ;

  ------------------------------------------------------------
  impure function GetAlertLogPrintIfHaveRequirements    return OsvvmOptionsType is
  ------------------------------------------------------------
  begin
  return AlertLogStruct.GetAlertLogPrintIfHaveRequirements ;
  end function GetAlertLogPrintIfHaveRequirements ;

  ------------------------------------------------------------
  impure function GetAlertLogDefaultPassedGoal    return integer is
  ------------------------------------------------------------
  begin
  return AlertLogStruct.GetAlertLogDefaultPassedGoal ;
  end function GetAlertLogDefaultPassedGoal ;

  ------------------------------------------------------------
  impure function GetAlertLogAlertPrefix          return string is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogAlertPrefix ;
  end function GetAlertLogAlertPrefix ;

  ------------------------------------------------------------
  impure function GetAlertLogLogPrefix            return string is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogLogPrefix ;
  end function GetAlertLogLogPrefix ;

  ------------------------------------------------------------
  impure function GetAlertLogReportPrefix return string is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogReportPrefix ;
  end function GetAlertLogReportPrefix ;

  ------------------------------------------------------------
  impure function GetAlertLogDoneName return string is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogDoneName ;
  end function GetAlertLogDoneName ;

  ------------------------------------------------------------
  impure function GetAlertLogPassName return string is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogPassName ;
  end function GetAlertLogPassName ;

  ------------------------------------------------------------
  impure function GetAlertLogFailName return string is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogFailName ;
  end function GetAlertLogFailName ;

  ------------------------------------------------------------
  impure function GetAlertLogWriteTimeLast        return OsvvmOptionsType is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogWriteTimeLast ;
  end function GetAlertLogWriteTimeLast ;


  ------------------------------------------------------------
  -- Package Local
  procedure ToLogLevel(LogLevel : out LogType; Name : in String; LogValid : out boolean) is
  ------------------------------------------------------------
  -- type LogType is (ALWAYS, DEBUG, FINAL, INFO, PASSED) ;  -- NEVER
  begin
    if    Name = "PASSED" then
      LogLevel := PASSED ;
      LogValid := TRUE ;
    elsif Name = "DEBUG" then
      LogLevel := DEBUG ;
      LogValid := TRUE ;
    elsif Name = "FINAL" then
      LogLevel := FINAL ;
      LogValid := TRUE ;
    elsif Name = "INFO"  then
      LogLevel := INFO ;
      LogValid := TRUE ;
    else
      LogLevel := ALWAYS ;
      LogValid := FALSE ;
    end if ;
  end procedure ToLogLevel ;

  ------------------------------------------------------------
  function IsLogEnableType (Name : String) return boolean is
  ------------------------------------------------------------
  -- type LogType is (ALWAYS, DEBUG, FINAL, INFO, PASSED) ;  -- NEVER
  begin
    if    Name = "PASSED" then return TRUE ;
    elsif Name = "DEBUG" then return TRUE ;
    elsif Name = "FINAL" then return TRUE ;
    elsif Name = "INFO"  then return TRUE ;
    end if ;
    return FALSE ;
  end function IsLogEnableType ;

  ------------------------------------------------------------
  procedure ReadLogEnables (file AlertLogInitFile : text) is
  --  Preferred Read format
  --  Line 1:  instance1_name log_enable log_enable log_enable
  --  Line 2:  instance2_name log_enable log_enable log_enable
  --  when reading multiple log_enables on a line, they must be separated by a space
  --
  --- Also supports alternate format from Lyle/....
  --  Line 1:  instance1_name
  --  Line 2:  log enable
  --  Line 3:  instance2_name
  --  Line 4:  log enable
  --
  ------------------------------------------------------------
    type     ReadStateType is (GET_ID, GET_ENABLE) ;
    variable ReadState        : ReadStateType := GET_ID ;
    variable buf              : line ;
    variable Empty            : boolean ;
    variable MultiLineComment : boolean := FALSE ;
    variable Name             : string(1 to 80) ;
    variable NameLen          : integer ;
    variable AlertLogID       : AlertLogIDType ;
    variable ReadAnEnable     : boolean ;
    variable LogValid         : boolean ;
    variable LogLevel         : LogType ;
  begin
    ReadState := GET_ID ;
    ReadLineLoop : while not EndFile(AlertLogInitFile) loop
      ReadLine(AlertLogInitFile, buf) ;
      if ReadAnEnable then
        -- Read one or more enable values, next line read AlertLog name
        -- Note that any newline with ReadAnEnable TRUE will result in
        -- searching for another AlertLogID name - this includes multi-line comments.
        ReadState := GET_ID ;
      end if ;

      ReadNameLoop : loop
        EmptyOrCommentLine(buf, Empty, MultiLineComment) ;
        next ReadLineLoop when Empty ;

        case ReadState is
          when GET_ID =>
            sread(buf, Name, NameLen) ;
            exit ReadNameLoop when NameLen = 0 ;
            AlertLogID := GetAlertLogID(Name(1 to NameLen), ALERTLOG_ID_NOT_ASSIGNED) ;
            ReadState := GET_ENABLE ;
            ReadAnEnable := FALSE ;

          when GET_ENABLE =>
            sread(buf, Name, NameLen) ;
            exit ReadNameLoop when NameLen = 0 ;
            ReadAnEnable := TRUE ;
--            if not IsLogEnableType(Name(1 to NameLen)) then
--              Alert(OSVVM_ALERTLOG_ID, "AlertLogPkg.ReadLogEnables: Found Invalid LogEnable: " & Name(1 to NameLen)) ;
--              exit ReadNameLoop ;
--            end if ;
----            Log(OSVVM_ALERTLOG_ID, "SetLogEnable(OSVVM_ALERTLOG_ID, " & Name(1 to NameLen) & ", TRUE) ;", DEBUG) ;
--            LogLevel := LogType'value("" & Name(1 to NameLen)) ;  -- "" & added for RivieraPro 2020.10
            ToLogLevel(LogLevel, Name(1 to NameLen), LogValid) ;
            exit ReadNameLoop when not LogValid ;
            SetLogEnable(AlertLogID, LogLevel, TRUE) ;
        end case ;
      end loop ReadNameLoop ;
    end loop ReadLineLoop ;
  end procedure ReadLogEnables ;

  ------------------------------------------------------------
  procedure ReadLogEnables (FileName : string) is
  ------------------------------------------------------------
    file AlertLogInitFile : text open READ_MODE is FileName ;
  begin
    ReadLogEnables(AlertLogInitFile) ;
  end procedure ReadLogEnables ;

  ------------------------------------------------------------
  function PathTail (A : string) return string is
  ------------------------------------------------------------
    alias aA : string(1 to A'length) is A ;
    variable LenA : integer := A'length ;
    variable Result : string(1 to A'length) ;
  begin
    if aA(LenA) = ':' then
      LenA := LenA - 1 ;
    end if ;
    for i in LenA downto 1 loop
      if aA(i) = ':' then
--!! GHDL Issue
--         return (1 to LenA - i => aA(i+1 to LenA)) ;
        Result(1 to LenA - i) := aA(i+1 to LenA) ;
        return Result(1 to LenA - i) ;
      end if ;
    end loop ;
    return aA(1 to LenA) ;
  end function PathTail ;


  ------------------------------------------------------------
  -- MetaMatch
  --   Similar to STD_MATCH, except
  --   it returns TRUE for U=U, X=X, Z=Z, and W=W
  --   All other values are consistent with STD_MATCH
  --   MetaMatch, BooleanTableType, and MetaMatchTable are derivatives
  --   of STD_MATCH from IEEE.Numeric_Std copyright by IEEE.
  --   Numeric_Std is also released under the Apache License, Version 2.0.
  --   Coding Styles were updated to match OSVVM
  ------------------------------------------------------------

  type BooleanTableType is array(std_ulogic, std_ulogic) of boolean;

  constant MetaMatchTable : BooleanTableType := (
    --------------------------------------------------------------------------
    -- U      X      0      1      Z      W      L      H      -
    --------------------------------------------------------------------------
    (TRUE,  FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE),  -- | U |
    (FALSE, TRUE,  FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE),  -- | X |
    (FALSE, FALSE, TRUE,  FALSE, FALSE, FALSE, TRUE,  FALSE, TRUE),  -- | 0 |
    (FALSE, FALSE, FALSE, TRUE,  FALSE, FALSE, FALSE, TRUE,  TRUE),  -- | 1 |
    (FALSE, FALSE, FALSE, FALSE, TRUE,  FALSE, FALSE, FALSE, TRUE),  -- | Z |
    (FALSE, FALSE, FALSE, FALSE, FALSE, TRUE,  FALSE, FALSE, TRUE),  -- | W |
    (FALSE, FALSE, TRUE,  FALSE, FALSE, FALSE, TRUE,  FALSE, TRUE),  -- | L |
    (FALSE, FALSE, FALSE, TRUE,  FALSE, FALSE, FALSE, TRUE,  TRUE),  -- | H |
    (TRUE,  TRUE,  TRUE,  TRUE,  TRUE,  TRUE,  TRUE,  TRUE,  TRUE)   -- | - |
    );

  function MetaMatch (l, r : std_ulogic) return boolean is
  begin
    return MetaMatchTable(l, r);
  end function MetaMatch;

  function MetaMatch (L, R : std_ulogic_vector) return boolean is
    alias aL : std_ulogic_vector(1 to L'length) is L;
    alias aR : std_ulogic_vector(1 to R'length) is R;
  begin
    if aL'length /= aR'length then
      --! log(OSVVM_ALERTLOG_ID, "AlertLogPkg.MetaMatch: Length Mismatch", DEBUG) ;
      return FALSE;
    else
      for i in aL'range loop
        if not (MetaMatchTable(aL(i), aR(i))) then
          return FALSE;
        end if;
      end loop;
      return TRUE;
    end if;
  end function MetaMatch;

  function MetaMatch (L, R : unresolved_unsigned) return boolean is
  begin
    return MetaMatch( std_ulogic_vector(L), std_ulogic_vector(R)) ;
  end function MetaMatch;

  function MetaMatch (L, R : unresolved_signed) return boolean is
  begin
    return MetaMatch( std_ulogic_vector(L), std_ulogic_vector(R)) ;
  end function MetaMatch;

  ------------------------------------------------------------
  -- Helper function for NewID in data structures
  function ResolvePrintParent (
  ------------------------------------------------------------
    UniqueParent : boolean ;
    PrintParent  : AlertLogPrintParentType
  ) return AlertLogPrintParentType is
    variable result : AlertLogPrintParentType ;
  begin
    if (not UniqueParent) and PrintParent = PRINT_NAME_AND_PARENT then
      result := PRINT_NAME ;
    else
      result := PrintParent ;
    end if ;
    return result ;
  end function ResolvePrintParent ;

  -- synthesis translate_on

  --  ------------------------------------------------------------
  -- Deprecated
  --

  ------------------------------------------------------------
  -- deprecated
  procedure AlertIf( condition : boolean ; AlertLogID  : AlertLogIDType ; Message : string ; Level : AlertType := ERROR ) is
  begin
    -- synthesis translate_off
    AlertIf( AlertLogID, condition, Message, Level) ;
    -- synthesis translate_on
  end procedure AlertIf ;

  ------------------------------------------------------------
  -- deprecated
  impure function  AlertIf( condition : boolean ; AlertLogID  : AlertLogIDType ; Message : string ; Level : AlertType := ERROR ) return boolean is
    variable result : boolean ;
  begin
    -- synthesis translate_off
    result := AlertIf( AlertLogID, condition, Message, Level) ;
    -- synthesis translate_on
    return result ;
  end function AlertIf ;

  ------------------------------------------------------------
  -- deprecated
  procedure AlertIfNot( condition : boolean ; AlertLogID  : AlertLogIDType ; Message : string ; Level : AlertType := ERROR ) is
  begin
    -- synthesis translate_off
    AlertIfNot( AlertLogID, condition, Message, Level) ;
    -- synthesis translate_on
  end procedure AlertIfNot ;

  ------------------------------------------------------------
  -- deprecated
  impure function  AlertIfNot( condition : boolean ; AlertLogID  : AlertLogIDType ; Message : string ; Level : AlertType := ERROR ) return boolean is
    variable result : boolean ;
  begin
    -- synthesis translate_off
    result := AlertIfNot( AlertLogID, condition, Message, Level) ;
    -- synthesis translate_on
    return result ;
  end function AlertIfNot ;

  ------------------------------------------------------------
  -- deprecated
  procedure AffirmIf(
    AlertLogID   : AlertLogIDType ;
    condition    : boolean ;
    Message      : string ;
    LogLevel     : LogType  ;  -- := PASSED
    AlertLevel   : AlertType := ERROR
  ) is
  begin
    -- synthesis translate_off
    if condition then
      -- PASSED.  Count affirmations and PASSED internal to LOG to catch all of them
      AlertLogStruct.Log(AlertLogID, Message, LogLevel) ; -- call log
    else
      AlertLogStruct.IncAffirmCount(AlertLogID) ;  -- count the affirmation
      AlertLogStruct.Alert(AlertLogID, Message, AlertLevel) ; -- signal failure
    end if ;
    -- synthesis translate_on
  end procedure AffirmIf ;

  ------------------------------------------------------------
  -- deprecated
  procedure AffirmIf( AlertLogID : AlertLogIDType ; condition : boolean ; Message : string ; AlertLevel : AlertType ) is
  begin
    -- synthesis translate_off
    AffirmIf(AlertLogID, condition, Message, PASSED, AlertLevel) ;
    -- synthesis translate_on
  end procedure AffirmIf ;

  ------------------------------------------------------------
  -- deprecated
  procedure AffirmIf(condition : boolean ; Message : string ;  LogLevel : LogType  ; AlertLevel : AlertType := ERROR) is
  begin
    -- synthesis translate_off
    AffirmIf(ALERT_DEFAULT_ID, condition, Message, LogLevel, AlertLevel) ;
    -- synthesis translate_on
  end procedure AffirmIf;

  ------------------------------------------------------------
  -- deprecated
  procedure AffirmIf(condition : boolean ; Message : string ;  AlertLevel : AlertType ) is
  begin
    -- synthesis translate_off
    AffirmIf(ALERT_DEFAULT_ID, condition, Message, PASSED, AlertLevel) ;
    -- synthesis translate_on
  end procedure AffirmIf;

end package body AlertLogPkg ;