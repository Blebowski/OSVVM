--
--  File Name:         VendorCovApiPkg_NVC.vhd
--  Design Unit Name:  VendorCovApiPkg
--  Revision:          NVC VERSION
--
--  Maintainer:
--
--  Package Defines
--     A set of foreign procedures that link OSVVM's CoveragePkg
--     coverage model creation and coverage capture with the
--     built-in capability of a simulator.
--
--
--  Revision History:      For more details, see CoveragePkg_release_notes.pdf
--    Date      Version    Description
--    11/2024   TBD        Initial version
--
--  This file is part of OSVVM.
--
--  Copyright (c) 2016 - 2020 by Aldec
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

library nvc;
use nvc.cover_pkg.all;

package VendorCovApiPkg is

  subtype VendorCovHandleType is integer;

  -- Types for how coverage bins are represented.  Matches OSVVM types.
  type VendorCovRangeType is record
      min: integer;
      max: integer;
  end record;

  type VendorCovRangeArrayType is array ( integer range <> ) of VendorCovRangeType;

  --  Create Initial Data Structure for Point/Item Functional Coverage Model
  --  Sets initial name of the coverage model if available
  impure function VendorCovPointCreate( name: string ) return VendorCovHandleType;

  --  Create Initial Data Structure for Cross Functional Coverage Model
  --  Sets initial name of the coverage model if available
  impure function VendorCovCrossCreate( name: string ) return VendorCovHandleType;

  --  Sets/Updates the name of the Coverage Model.
  --  Should not be called until the data structure is created by VendorCovPointCreate or VendorCovCrossCreate.
  --  Replaces name that was set by VendorCovPointCreate or VendorCovCrossCreate.
  procedure VendorCovSetName( obj: VendorCovHandleType; name: string );

  --  Add a bin or set of bins to either a Point/Item or Cross Functional Coverage Model
  --  Checking for sizing that is different from original sizing already done in OSVVM CoveragePkg
  --  It is important to maintain an index that corresponds to the order the bins were entered as
  --  that is used when coverage is recorded.
  procedure VendorCovBinAdd( obj: VendorCovHandleType; bins: VendorCovRangeArrayType; Action: integer; atleast: integer; name: string );

  --  Increment the coverage of bin identified by index number.
  --  Index ranges from 1 to Number of Bins.
  --  Index corresponds to the order the bins were entered (starting from 1)
  procedure VendorCovBinInc( obj: VendorCovHandleType; index: integer );

  -- Action (integer):
  -- constant COV_COUNT   : integer := 1;
  -- constant COV_IGNORE  : integer := 0;
  -- constant COV_ILLEGAL : integer := -1;

  -------------------------------------------------------------------------------------------------
  -- Glue code
  -------------------------------------------------------------------------------------------------

  -- Get name (hoepfully unique) suffix for OSVVM cover item. Appends:
  --    - Name of calling process
  --    - Name of underlying OSVVM signal / variable declaration
  impure function GetOSVVMObjectSuffix return string;
  attribute foreign of GetOSVVMObjectSuffix : function
        is "INTERNAL _nvc_get_osvvm_object_suffix";

  -- Identifier normalization:
  --    - Remove spaces
  --    - Upper-case
  function NormalizeOSVVMName(in_name : in string) return string;

  -- Dynamic array with mapping between "t_scope_handle" and "VendorCovHandleType"
  type t_scope_handle_array is array (natural range <>) of t_scope_handle;
  type t_scope_handle_array_ptr is access t_scope_handle_array;

  -- Array with hadle mapping
  type HandleMapListType is protected
    procedure AddNVCHandle(
      variable nvc_handle   : in  t_scope_handle;
      variable osvvm_handle : out VendorCovHandleType
    );

    procedure GetNVCHandle(
      constant osvvm_handle : in  VendorCovHandleType;
      variable nvc_handle   : out t_scope_handle
    );
  end protected;

end package;

package body VendorCovApiPkg is

  -------------------------------------------------------------------------------------------------
  -- Array with mapping between "t_scope_handle" and "VendorCovHandleType"
  -------------------------------------------------------------------------------------------------
  type HandleMapListType is protected body

    variable handle_arr : t_scope_handle_array_ptr := null;
    variable n_handles  : integer := 0;

    procedure AddNVCHandle(
      variable nvc_handle   : in  t_scope_handle;
      variable osvvm_handle : out VendorCovHandleType
    ) is
      variable tmp : t_scope_handle_array_ptr;
    begin
      n_handles := n_handles + 1;

      -- Allocate new array larger by 1
      tmp := new t_scope_handle_array(0 to n_handles - 1);

      -- Copy previous array and free it
      if (handle_arr /= null) then
        for i in 0 to n_handles - 2 loop
          tmp.all(i) := handle_arr.all(i);
        end loop;
        deallocate(handle_arr);
      end if;

      -- Add last element and point back
      tmp.all(n_handles - 1) := nvc_handle;
      handle_arr := tmp;

      osvvm_handle := n_handles - 1;
    end;

    procedure GetNVCHandle(
      constant osvvm_handle : in  VendorCovHandleType;
      variable nvc_handle   : out t_scope_handle
    ) is
    begin
      if (integer(osvvm_handle) > n_handles - 1) then
        report "Invalid OSVVM coverage scope handle: " & integer'image(osvvm_handle)
        severity failure;
      end if;
      nvc_handle := handle_arr(osvvm_handle);
    end;

  end protected body;

  function NormalizeOSVVMName(in_name : in string) return string is
    variable out_name : string(1 to in_name'length);
    constant offset   : natural := character'pos('a') - character'pos('A');
  begin
    for i in 1 to in_name'length loop
      -- TODO: Should we handle other special characters ?
      if (in_name(i) = ' ') then
        out_name(i) := '_';
      elsif (in_name(i) >= 'a' and in_name(i) <= 'z') then
        out_name(i) := character'val(character'pos(in_name(i)) - offset);
      else
        out_name(i) := in_name(i);
      end if;
    end loop;
    return  out_name;
  end;

  shared variable scope_arr : HandleMapListType;



  -------------------------------------------------------------------------------------------------
  -- API implementation
  -------------------------------------------------------------------------------------------------

  impure function VendorCovPointCreate( name: string ) return VendorCovHandleType is
    variable scope_handle : t_scope_handle;
    variable rv : VendorCovHandleType;
  begin
    if (name /= "") then
      create_cover_scope (scope_handle, GetOSVVMObjectSuffix & '.' & NormalizeOSVVMName(name));
    else
      create_cover_scope (scope_handle, GetOSVVMObjectSuffix);
    end if;
    scope_arr.AddNVCHandle(scope_handle, rv);
    return rv;
  end function;

   --  Create Initial Data Structure for Cross Functional Coverage Model
   --  Sets initial name of the coverage model if available
   impure function VendorCovCrossCreate( name: string ) return VendorCovHandleType is
   begin
    return 0;
   end function;

   --  Sets/Updates the name of the Coverage Model.
   --  Should not be called until the data structure is created by VendorCovPointCreate or VendorCovCrossCreate.
   --  Replaces name that was set by VendorCovPointCreate or VendorCovCrossCreate.
   procedure VendorCovSetName( obj: VendorCovHandleType; name: string ) is
   begin
   end procedure;

   --  Add a bin or set of bins to either a Point/Item or Cross Functional Coverage Model
   --  Checking for sizing that is different from original sizing already done in OSVVM CoveragePkg
   --  It is important to maintain an index that corresponds to the order the bins were entered as
   --  that is used when coverage is recorded.
   procedure VendorCovBinAdd( obj: VendorCovHandleType; bins: VendorCovRangeArrayType; Action: integer; atleast: integer; name: string ) is
    variable scope_handle : t_scope_handle;
    variable item         : t_item_handle;
   begin
    scope_arr.GetNVCHandle(obj, scope_handle);
    add_cover_item (scope_handle, item, NormalizeOSVVMName(name));
   end procedure;

   --  Increment the coverage of bin identified by index number.
   --  Index ranges from 1 to Number of Bins.
   --  Index corresponds to the order the bins were entered (starting from 1)
   procedure VendorCovBinInc( obj: VendorCovHandleType; index: integer ) is
   begin
   end procedure;

   impure function GetOSVVMObjectSuffix return string is
   begin
    return "";
   end function;

end package body VendorCovApiPkg ;
