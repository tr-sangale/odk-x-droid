/*
 * Copyright (C) 2015 University of Washington
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); you may not
 * use this file except in compliance with the License. You may obtain a copy of
 * the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 * License for the specific language governing permissions and limitations under
 * the License.
 */
package org.opendatakit.database.service;

import java.util.List;

import android.os.ParcelUuid;

import org.opendatakit.database.data.OrderedColumns;
import org.opendatakit.database.data.ColumnList;
import org.opendatakit.database.data.TableDefinitionEntry;
import org.opendatakit.database.queries.BindArgs;
import org.opendatakit.database.queries.QueryBounds;
import org.opendatakit.database.service.DbHandle;
import org.opendatakit.database.service.DbChunk;
import org.opendatakit.database.service.TableHealthInfo;
import org.opendatakit.database.data.KeyValueStoreEntry;

/**
* any interface that begins privileged.... will run with elevated privileges.
* I.e., it has no user-permissions restrictions imposed upon it. For the most
* part, these should be called only by:
* (1) SYNC
* (2) InitializationTask
* (3) CSV Import
*/
interface IDbInterface {

 /**
   * Return the active user or "anonymous" if the user
   * has not been authenticated against the server.
   *
   * @param appName
   *
   * @return the user reported from the server or "anonymous" if
   * server authentication has not been completed.
   */
  String getActiveUser(in String appName);

  /**
   * Return the roles and groups of a verified username or google account.
   * If the username or google account have not been verified,
   * or if the server settings specify to use an anonymous user,
   * then return an empty string.
   *
   * @param appName
   *
   * @return null or JSON serialization of an array of ROLES and GROUPS.
   *
   * See RoleConsts for possible values.
   */
  String getRolesList(in String appName);

  /**
   * Return the current user's default group.
   * This will be an empty string if the server does not support user-defined groups.
   *
   * @return null or the name of the default group.
   */
  String getDefaultGroup(in String appName);

  /**
   * Return the users configured on the server if the current
   * user is verified to have Tables Super-user, Administer Tables or
   * Site Administrator roles. Otherwise, returns information about
   * the current user. If the user is syncing anonymously with the
   * server, this returns an empty string.
   *
   * @param appName
   *
   * @return null or DbChunk of JSON serialization of an array of objects
   * structured as { "user_id": "...", "full_name": "...", "roles": ["...",...] }
   */
  DbChunk getUsersList(in String appName);

  /**
   * Obtain a databaseHandleName
   *
   * @param appName
   *
   * @return dbHandleName
   */
  DbHandle openDatabase(in String appName);

  /**
   * Release the databaseHandle. Will roll back any outstanding transactions
   * and release/close the database handle.
   *
   * @param appName
   * @param dbHandleName
   */
   void closeDatabase(in String appName, in DbHandle dbHandleName);

  /**
   * Create a local only table and prepend the given id with an "L_"
   *
   * @param appName
   * @param dbHandleName
   * @param tableId
   * @param columns
   * @return
   */
  DbChunk createLocalOnlyTableWithColumns(in String appName, in DbHandle dbHandleName,
      in String tableId, in ColumnList columns);

  /**
    * Drop the given local only table
    *
    * @param appName
    * @param dbHandleName
    * @param tableId
    */
  void deleteLocalOnlyTable(in String appName, in DbHandle dbHandleName,
     in String tableId);

  /**
   * Insert a row into a local only table
   *
   * @param appName
   * @param dbHandleName
   * @param tableId
   * @param rowValues
   * @throws ActionNotAuthorizedException
   */
  void insertLocalOnlyRow(in String appName, in DbHandle dbHandleName, in String tableId,
     in ContentValues rowValues);

  /**
   * Update a row in a local only table
   *
   * @param appName
   * @param dbHandleName
   * @param tableId
   * @param rowValues
   * @param whereClause
   * @param sqlBindArgs
   * @throws ActionNotAuthorizedException
   */
  void updateLocalOnlyRow(in String appName, in DbHandle dbHandleName, in String tableId,
        in ContentValues rowValues, in String whereClause, in BindArgs sqlBindArgs);

  /**
   * Delete a row in a local only table
   *
   * @param appName
   * @param dbHandleName
   * @param tableId
   * @param whereClause
   * @param sqlBindArgs
   * @throws ActionNotAuthorizedException
   */
  void deleteLocalOnlyRow(in String appName, in DbHandle dbHandleName, in String tableId,
        in String whereClause, in BindArgs sqlBindArgs);

  /**
   * SYNC Only. ADMIN Privileges
   *
   * Call this when the schemaETag for the given tableId has changed on the server.
   *
   * This is a combination of:
   *
   * Clean up this table and set the dataETag to null.
   *
   * changeDataRowsToNewRowState(sc.getAppName(), db, tableId);
   *
   * we need to clear out the dataETag so
   * that we will pull all server changes and sync our properties.
   *
   * updateTableETags(sc.getAppName(), db, tableId, schemaETag, null);
   *
   * Although the server does not recognize this tableId, we can
   * keep our record of the ETags for the table-level files and
   * manifest. These may enable us to short-circuit the restoration
   * of the table-level files should another client be simultaneously
   * trying to restore those files to the server.
   *
   * However, we do need to delete all the instance-level files,
   * as these are tied to the schemaETag we hold, and that is now
   * invalid.
   *
   * if the local table ever had any server sync information for this
   * host then clear it. If the user changed the server URL, we have
   * already cleared this information.
   *
   * Clearing it here handles the case where an admin deleted the
   * table on the server and we are now re-pushing that table to
   * the server.
   *
   * We do not know whether the rows on the device match those on the server.
   * We will find out later, in the course of the sync.
   *
   * if (tableInstanceFilesUri != null) {
   *   deleteAllSyncETagsUnderServer(sc.getAppName(), db, tableInstanceFilesUri);
   * }
   */
  void privilegedServerTableSchemaETagChanged(in String appName, in DbHandle dbHandleName,
    in String tableId, in String schemaETag, in String tableInstanceFilesUri);

  /**
   * Compute the app-global choiceListId for this choiceListJSON
   * and register the tuple of (choiceListId, choiceListJSON).
   * Return choiceListId.
   *
   * @param appName
   * @param dbHandleName
   * @param choiceListJSON -- the actual JSON choice list text.
   * @return choiceListId -- the unique code mapping to the choiceListJSON
   */
  String setChoiceList(in String appName, in DbHandle dbHandleName,
   in String choiceListJSON );

  /**
   * Return the choice list JSON corresponding to the choiceListId
   *
   * @param appName
   * @param dbHandleName
   * @param choiceListId -- the md5 hash of the choiceListJSON
   * @return null or DbChunk of choiceListJSON -- the actual JSON choice list text.
   */
  DbChunk getChoiceList(in String appName, in DbHandle dbHandleName, in String choiceListId );

  /**
   * If the tableId is not recorded in the TableDefinition metadata table, then
   * create the tableId with the indicated columns. This will synthesize
   * reasonable metadata KVS entries for table.
   * 
   * If the tableId is present, then this is a no-op.
   * 
   * @param appName
   * @param dbHandleName
   * @param tableId
   * @param columns simple transport wrapper for List<Columns>
   * @return the OrderedColumns of the user columns in the table.
   */
  DbChunk createOrOpenTableWithColumns(in String appName, in DbHandle dbHandleName,
      in String tableId, in ColumnList columns);

	/**
   * If the tableId is not recorded in the TableDefinition metadata table, then
   * create the tableId with the indicated columns. And apply the supplied KVS
   * settings. If some are missing, this will synthesize reasonable metadata KVS
   * entries for table.
   *
   * If the table is present, this will delete and replace the KVS with the given KVS
   * entries if the clear flag is true
	 *
   * @param appName
   * @param dbHandleName
   * @param tableId
   * @param columns simple transport wrapper for List<Columns>
   * @param metaData a List<KeyValueStoreEntry>
   * @param clear if true then delete the existing set of values for this
   *          tableId before inserting or replacing with the new ones.
   * @return the OrderedColumns of the user columns in the table.
	 */
  DbChunk createOrOpenTableWithColumnsAndProperties(in String appName,
      in DbHandle dbHandleName,
      in String tableId, in ColumnList columns,
      in List<KeyValueStoreEntry> metaData, in boolean clear);

  /**
   * Rescan the config directory tree of the given tableId and update the forms table
   * with revised information from the formDef.json files that it contains.
   *
   * @param appName
   * @param dbHandleName
   * @param tableId
   * @return true if there were no problems
   */
  boolean rescanTableFormDefs(in String appName, in DbHandle dbHandleName, in String tableId);

  /**
   * Drop the given tableId and remove all the files (both configuration and
   * data attachments) associated with that table.
   * 
   * @param appName
   * @param dbHandleName
   * @param tableId
   */
  void deleteTableAndAllData(in String appName, in DbHandle dbHandleName,
      in String tableId);
		
  /**
   * The deletion filter includes all non-null arguments. If all arguments
   * (except the db) are null, then all properties are removed.
   * 
   * @param appName
   * @param dbHandleName
   * @param tableId
   * @param partition
   * @param aspect
   * @param key
   */
  void deleteTableMetadata(in String appName, in DbHandle dbHandleName,
      in String tableId, in String partition, in String aspect, in String key);

  /**
   * Return an array of the admin columns that must be present in
   * every database table.
   * 
   * @return
   */
  DbChunk getAdminColumns();
		
  /**
   * Return all the columns in the given table, including any metadata columns.
   * This does a direct query against the database and is suitable for accessing
   * non-managed tables. It does not access any metadata and therefore will not
   * report non-unit-of-retention (grouping) columns.
   * 
   * @param appName
   * @param dbHandleName
   * @param tableId
   * @return
   */
  DbChunk getAllColumnNames(in String appName, in DbHandle dbHandleName,
      in String tableId);

  /**
   * Return all the tableIds in the database.
   * 
   * @param appName
   * @param dbHandleName
   * @return List<String> of tableIds
   */
  DbChunk getAllTableIds(in String appName, in DbHandle dbHandleName);
  
  /**
   * @param appName
   * @param dbHandleName
   * @param tableId
   * @param partition
   * @param aspect
   * @param key
   *
   * @return list of KeyValueStoreEntry values matching the filter criteria
   */
  DbChunk getTableMetadata(in String appName, in DbHandle dbHandleName,
      in String tableId, in String partition, in String aspect, in String key);

  /**
   * @param appName
   * @param dbHandleName
   * @param tableId
   * @param revId
   * @param partition
   * @param aspect
   * @param key
   *
   * @return list of KeyValueStoreEntry values matching the filter criteria, or an empty list if
   * nothing has changed
   */
  DbChunk getTableMetadataIfChanged(in String appName, in DbHandle dbHandleName,
      in String tableId, in String revId);

  /**
   * Return an array of the admin columns that should be exported to
   * a CSV file. This list excludes the SYNC_STATE and CONFLICT_TYPE columns.
   * 
   * @return
   */
  DbChunk getExportColumns();

  /**
   * Get the table definition entry for a tableId. This specifies the schema
   * ETag, the data-modification ETag, and the date-time of the last successful
   * sync of the table to the server.
   * 
   * @param appName
   * @param dbHandleName
   * @param tableId
   * @return
   */
  DbChunk getTableDefinitionEntry(in String appName, in DbHandle dbHandleName,
      in String tableId);

  /**
   * Return the a table's health status.
   *
   * @param appName
   * @param dbHandleName
   * @param tableId
   *
   * @return the first chunk of the TableHealthInfo record for this appName and tableId
   */
  DbChunk getTableHealthStatus(in String appName, in DbHandle dbHandleName, in String tableId);

  /**
   * Return the list of all tables and their health status.
   *
   * @param appName
   * @param dbHandleName
   *
   * @return the first chunk of the list of TableHealthInfo records for this appName
   */ 
  DbChunk getTableHealthStatuses(in String appName, in DbHandle dbHandleName);
  
    /**
   * Retrieve the list of user-defined columns for a tableId using the metadata
   * for that table. Returns the unit-of-retention and non-unit-of-retention
   * (grouping) columns.
   * 
   * @param appName
   * @param dbHandleName
   * @param tableId
   * @return
   */
  DbChunk getUserDefinedColumns(in String appName, in DbHandle dbHandleName,
      in String tableId);
      
  /**
   * Verifies that the tableId exists in the database.
   *
   * @param appName
   * @param dbHandleName
   * @param tableId
   * @return true if table is listed in table definitions.
   */
  boolean hasTableId(in String appName, in DbHandle dbHandleName, 
      in String tableId);

  /* rawQuery */

  /**
   * Get a {@link BaseTable} for the result set of an arbitrary sql query
   * and bind parameters.
   *
   * The sql query can be arbitrarily complex and can include joins, unions, etc.
   * The data are returned as string values.
   *
   * @param appName
   * @param dbHandleName
   * @param sqlCommand
   * @param sqlBindArgs
   * @param tableId -- optional. If not null and _default_access, _owner and _sync_state are
   *       present in the result cursor, append an _effective_access column with r, rw, or rwd
   *       values.
   * @return
   */
  DbChunk simpleQuery(in String appName, in DbHandle dbHandleName,
      in String sqlCommand, in BindArgs sqlBindArgs, in QueryBounds sqlQueryBounds,
      in String tableId);

  /**
   * Privileged version of the above interface.
   *
   * Get a {@link BaseTable} for the result set of an arbitrary sql query
   * and bind parameters.
   *
   * The sql query can be arbitrarily complex and can include joins, unions, etc.
   * The data are returned as string values.
   *
   * @param appName
   * @param dbHandleName
   * @param sqlCommand
   * @param sqlBindArgs
   * @param tableId -- optional. If not null and _default_access, _owner and _sync_state are
   *       present in the result cursor, append an _effective_access column with r, rw, or rwd
   *       values.
   * @return
   */
  DbChunk privilegedSimpleQuery(in String appName, in DbHandle dbHandleName,
      in String sqlCommand, in BindArgs sqlBindArgs, in QueryBounds sqlQueryBounds,
      in String tableId);

  /**
   * Privileged execute of an arbitrary SQL command.
   * For obvious reasons, this is very dangerous!
   *
   * The sql command can be any valid SQL command that does not return a result set.
   * No data is returned (e.g., insert into table ... or similar).
   *
   * @param appName
   * @param dbHandleName
   * @param sqlCommand
   * @param sqlBindArgs
   */
  void privilegedExecute(in String appName, in DbHandle dbHandleName,
      in String sqlCommand, in BindArgs sqlBindArgs);

  /**
   * Insert or update a single table-level metadata KVS entry.
   * 
   * @param appName
   * @param dbHandleName
   * @param entry
   */
  void replaceTableMetadata(in String appName, in DbHandle dbHandleName,
      in KeyValueStoreEntry entry);

  /**
   * Insert or update a list of table-level metadata KVS entries. If clear is
   * true, then delete the existing set of values for this tableId before
   * inserting the new values.
   * 
   * @param appName
   * @param dbHandleName
   * @param tableId
   * @param metadata
   *          a List<KeyValueStoreEntry>
   * @param clear
   *          if true then delete the existing set of values for this tableId
   *          before inserting the new ones.
   */
  void replaceTableMetadataList(in String appName, in DbHandle dbHandleName,
      in String tableId,
      in List<KeyValueStoreEntry> metaData, in boolean clear);

  /**
   * Atomically delete all the fields under the given (tableId, partition, aspect)
   * and replace with the supplied values.
   *
   * @param appName
   * @param dbHandleName
   * @param tableId
   * @param partition
   * @param aspect
   * @param metadata
   *          a List<KeyValueStoreEntry>
   */
  void replaceTableMetadataSubList(in String appName, in DbHandle dbHandleName,
      in String tableId, in String partition, in String aspect,
      in List<KeyValueStoreEntry> metaData);

  /**
   * SYNC Only. ADMIN Privileges
   *
   * Update the schema and data-modification ETags of a given tableId.
   *
   * @param appName
   * @param dbHandleName
   * @param tableId
   * @param schemaETag
   * @param lastDataETag
   */
  void privilegedUpdateTableETags(in String appName, in DbHandle dbHandleName,
      in String tableId, in String schemaETag,
      in String lastDataETag);

  /**
   * SYNC Only. ADMIN Privileges
   *
   * Update the timestamp of the last entirely-successful synchronization
   * attempt of this table.
   *
   * @param appName
   * @param dbHandleName
   * @param tableId
   */
  void privilegedUpdateTableLastSyncTime(in String appName, in DbHandle dbHandleName, in
  String tableId);

  /////////////////////////////////////////////////////////////////////////////////////
  // Row level changes
  /////////////////////////////////////////////////////////////////////////////////////

  /**
   *
   * @param appName
   * @param dbHandleName
   * @param tableId
   * @param rowId
   * @return the sync state of the row (use {@link SyncState.valueOf()} to reconstruct), or null if the
   *         row does not exist.
   */
  String getSyncState(in String appName, in DbHandle dbHandleName,
      in String tableId, in String rowId);

  /**
   * SYNC Only. ADMIN Privileges
   *
   * Update the ETag and SyncState of a given rowId. There should be exactly one
   * record for this rowId in thed database (i.e., no conflicts or checkpoints).
   *
   * @param appName
   * @param dbHandleName
   * @param tableId
   * @param rowId
   * @param rowETag
   * @param syncState - the SyncState.name()
   */
  void privilegedUpdateRowETagAndSyncState(in String appName, in DbHandle dbHandleName,
      in String tableId, in String rowId, in String rowETag, in String syncState);


  /**
   * Return the row(s) for the given tableId and rowId. If the row has
   * checkpoints or conflicts, the returned UserTable will have more than one
   * Row returned. Otherwise, it will contain a single row.
   *
   * @param appName
   * @param dbHandleName
   * @param tableId
   * @param rowId
   * @return one or more rows (depending upon sync conflict and edit checkpoint states)
   */
  DbChunk getRowsWithId(in String appName, in DbHandle dbHandleName,
      in String tableId, in String rowId);

  /**
   * CSV UTIL
   * For detecting existing rows when importing csvs.
    *
   * Return the row(s) for the given tableId and rowId. If the row has
   * checkpoints or conflicts, the returned UserTable will have more than one
   * Row returned. Otherwise, it will contain a single row.
   *
   * @param appName
   * @param dbHandleName
   * @param tableId
   * @param rowId
   * @return one or more rows (depending upon sync conflict and edit checkpoint states)
   */
  DbChunk privilegedGetRowsWithId(in String appName, in DbHandle dbHandleName,
      in String tableId, in String rowId);

  /**
   * Return the row with the most recent changes for the given tableId and rowId.
   * If the row has conflicts, it throws an exception. Otherwise, it returns the
   * most recent checkpoint or non-checkpoint value; it will contain a single row.
   *
   * @param appName
   * @param dbHandleName
   * @param tableId
   * @param rowId
   * @return
   */
  DbChunk getMostRecentRowWithId(in String appName, in DbHandle dbHandleName,
      in String tableId, in String rowId);

  /**
   * SYNC ONLY
   *
   * A combination of:
   *
   * deleteServerConflictRowWithId(appName, db, tableId, rowId)
   * getRowWithId(appname, db, tableId, rowId)
   * if (canresolve) {
   *    update with resolution
   * } else {
   *    placeRowIntoConflict(appName, db, tableId, rowId, localRowConflictType)
   * and, for the values which are the server row changes:
   *    insertDataIntoExistingTableWithId( appName, db, tableId, orderedColumns, values, rowId)
   * }
   *
   * Change the conflictType for the given row from null (not in conflict) to
   * the specified one.
   *
   * @param appName
   * @param dbHandleName
   * @param tableId
   * @param cvValues  server's field values for this row
   * @param rowId
   */
  DbChunk privilegedPerhapsPlaceRowIntoConflictWithId(in String appName, in DbHandle dbHandleName,
      in String tableId, in ContentValues cvValues,
      in String rowId);

  /**
   * SYNC, CSV Import ONLY
   *
   * Insert the given rowId with the values in the cvValues. This is data from
   * the server. All metadata values must be specified in the cvValues (even null values).
   *
   * If a row with this rowId is present, then an exception is thrown.
   *
   * @param appName
   * @param dbHandleName
   * @param tableId
   * @param cvValues
   * @param rowId
   * @return single-row table with the content of the inserted row
   */
  DbChunk privilegedInsertRowWithId(in String appName, in DbHandle dbHandleName,
  	  in String tableId, in ContentValues cvValues, in String rowId,
  	  boolean asCsvRequestedChange);


  /**
   * Inserts a checkpoint row for the given rowId in the tableId. Checkpoint
   * rows are created by ODK Survey to hold intermediate values during the
   * filling-in of the form. They act as restore points in the Survey, should
   * the application die.
   *
   * @param appName
   * @param dbHandleName
   * @param tableId
   * @param cvValues
   * @param rowId
   * @return single-row table with the content of the inserted checkpoint
   */
  DbChunk insertCheckpointRowWithId(in String appName, in DbHandle dbHandleName,
      in String tableId, in ContentValues cvValues, in String rowId);

  /**
   * Insert the given rowId with the values in the cvValues. If certain metadata
   * values are not specified in the cvValues, then suitable default values may
   * be supplied for them.
   *
   * If a row with this rowId and certain matching metadata fields is present,
   * then an exception is thrown.
   *
   * @param appName
   * @param dbHandleName
   * @param tableId
   * @param cvValues
   * @param rowId
   * @return single-row table with the content of the inserted row
   */
  DbChunk insertRowWithId(in String appName, in DbHandle dbHandleName,
  	  in String tableId, in ContentValues cvValues, in String rowId);


  /**
   * Delete any checkpoint rows for the given rowId in the tableId. Checkpoint
   * rows are created by ODK Survey to hold intermediate values during the
   * filling-in of the form. They act as restore points in the Survey, should
   * the application die.
   *
   * @param appName
   * @param dbHandleName
   * @param tableId
   * @param rowId
   */
  DbChunk deleteAllCheckpointRowsWithId(in String appName, in DbHandle dbHandleName,
      in String tableId, in String rowId);

  /**
   * Delete any checkpoint rows for the given rowId in the tableId. Checkpoint
   * rows are created by ODK Survey to hold intermediate values during the
   * filling-in of the form. They act as restore points in the Survey, should
   * the application die.
   *
   * @param appName
   * @param dbHandleName
   * @param tableId
   * @param rowId
   */
  DbChunk deleteLastCheckpointRowWithId(in String appName, in DbHandle dbHandleName,
      in String tableId, in String rowId);

 /**
   * Delete the specified rowId in this tableId. Deletion respects sync
   * semantics. If the row is in the SyncState.new_row state, then the row and
   * its associated file attachments are immediately deleted. Otherwise, the row
   * is placed into the SyncState.deleted state and will be retained until the
   * device can delete the record on the server.
   * <p>
   * If you need to immediately delete a record that would otherwise sync to the
   * server, call updateRowETagAndSyncState(...) to set the row to
   * SyncState.new_row, and then call this method and it will be immediately
   * deleted (in this case, unless the record on the server was already deleted,
   * it will remain and not be deleted during any subsequent synchronizations).
   *
   * @param appName
   * @param dbHandleName
   * @param tableId
   * @param rowId
   */
  DbChunk deleteRowWithId(in String appName, in DbHandle dbHandleName,
      in String tableId, in String rowId);


  /**
   * SYNC, conflict resolution ONLY
   *
   * Delete the specified rowId in this tableId. This is enforcing the server
   * state on the device. I.e., the sync interaction instructed us to delete
   * this row.
   *
   * @param appName
   * @param dbHandleName
   * @param tableId
   * @param rowId
   */
  DbChunk privilegedDeleteRowWithId(in String appName, in DbHandle dbHandleName,
      in String tableId, in String rowId);


  /**
   * Update all rows for the given rowId to SavepointType 'INCOMPLETE' and
   * remove all but the most recent row. When used with a rowId that has
   * checkpoints, this updates to the most recent checkpoint and removes any
   * earlier checkpoints, incomplete or complete savepoints. Otherwise, it has
   * the general effect of resetting the rowId to an INCOMPLETE state.
   * 
   * @param appName
   * @param dbHandleName
   * @param tableId
   * @param rowId
   * @return single-row table with the content of the saved-as-incomplete row
   */
  DbChunk saveAsIncompleteMostRecentCheckpointRowWithId(
  	  in String appName, in DbHandle dbHandleName,
      in String tableId, in String rowId);

 /**
   * Update all rows for the given rowId to SavepointType 'INCOMPLETE' and
   * remove all but the most recent row. When used with a rowId that has
   * checkpoints, this updates to the most recent checkpoint and removes any
   * earlier checkpoints, incomplete or complete savepoints. Otherwise, it has
   * the general effect of resetting the rowId to an INCOMPLETE state.
   *
   * @param appName
   * @param dbHandleName
   * @param tableId
   * @param rowId
   * @return single-row table with the content of the saved-as-incomplete row
   */
  DbChunk saveAsCompleteMostRecentCheckpointRowWithId(
  	  in String appName, in DbHandle dbHandleName,
      in String tableId, in String rowId);

  /**
   * Update the given rowId with the values in the cvValues. If certain metadata
   * values are not specified in the cvValues, then suitable default values may
   * be supplied for them. Furthermore, if the cvValues do not specify certain
   * metadata fields, then an exception may be thrown if there are more than one
   * row matching this rowId.
   * 
   * @param appName
   * @param dbHandleName
   * @param tableId
   * @param cvValues
   * @param rowId
   * @return single-row table with the content of the saved-as-incomplete row
   */
  DbChunk updateRowWithId(in String appName, in DbHandle dbHandleName,
      in String tableId,
      in ContentValues cvValues, in String rowId);

  /**
   * Delete the local and server conflict records to resolve a server conflict
   *
   * A combination of primitive actions, all performed in one transaction:
   *
   * // delete the record of the server row
   * deleteServerConflictRowWithId(appName, dbHandleName, tableId, rowId);
   *
   * // move the local record into the 'new_row' sync state
   * // so it can be physically deleted.
   * updateRowETagAndSyncState(appName, dbHandleName, tableId, rowId, null,
   *                           SyncState.new_row.name());
   * // move the local conflict back into the normal (null) state
   * deleteRowWithId(appName, dbHandleName, tableId, rowId);
   *
   * @param appName
   * @param dbHandleName
   * @param tableId
   * @param rowId
   */
  void resolveServerConflictWithDeleteRowWithId(in String appName,
        in DbHandle dbHandleName, in String tableId,
  	    in String rowId);

  /**
   * Resolve the server conflict by taking the local changes.
   * If the local changes are to delete this record, the record will be deleted
   * upon the next successful sync.
   *
   * @param appName
   * @param dbHandleName
   * @param tableId
   * @param rowId
   */
  void resolveServerConflictTakeLocalRowWithId(in String appName,
        in DbHandle dbHandleName, in String tableId,
  	    in String rowId);

  /**
   * Resolve the server conflict by taking the local changes plus a value map
   * of select server field values.  This map should not update any metadata
   * fields -- it should just contain user data fields.
   *
   * It is an error to call this if the local change is to delete the row.
   *
   * @param appName
   * @param dbHandleName
   * @param tableId
   * @param cvValues
   * @param rowId
   */
  void resolveServerConflictTakeLocalRowPlusServerDeltasWithId(in String appName,
        in DbHandle dbHandleName, in String tableId, in ContentValues cvValues,
  	    in String rowId);

  /**
   * Resolve the server conflict by taking the server changes.  This may delete the local row.
   *
   * @param appName
   * @param dbHandleName
   * @param tableId
   * @param rowId
   */
  void resolveServerConflictTakeServerRowWithId(in String appName,
        in DbHandle dbHandleName, in String tableId,
  	    in String rowId);

  /************************************
   * Sync Communications Tracking Tables.
   *
   * These APIs manipulate the table holding 
   * the most current ETag for any documents
   * transmitted between the server and client.
   *
   * By supplying an If-Modified: ETAG
   * header, the server is able to avoid
   * sending the document to the client
   * and instead return a NOT_MODIFIED
   * response.
   ************************************/

  /**
   * Remove app and table level manifests. Invoked when we select reset configuration
   * and the initialization task is executed.
   *
   * @param appName
   * @param dbHandleName
   */
  void deleteAppAndTableLevelManifestSyncETags(in String appName, in DbHandle dbHandleName);

  /**
   * Forget the document ETag values for the given tableId on all servers.
   * Used when deleting a table. Exposed mainly for integration testing.
   *
   * @param appName
   * @param dbHandleName
   * @param tableId
   */
  void deleteAllSyncETagsForTableId(in String appName, in DbHandle dbHandleName, in String tableId);

  /**
   * Forget the document ETag values for everything except the specified Uri.
   * Call this when the server URI we are syncing against has changed.
   *
   * @param appName
   * @param dbHandleName
   * @param verifiedUri (e.g., https://opendatakit-tablesdemo.appspot.com)
   */
  void deleteAllSyncETagsExceptForServer(in String appName, in DbHandle dbHandleName,
  	  in String verifiedUri);

  /**
   * Forget the document ETag values for everything under the specified Uri.
   *
   * @param appName
   * @param dbHandleName
   * @param verifiedUri (e.g., https://opendatakit-tablesdemo.appspot.com)
   */
  void deleteAllSyncETagsUnderServer(in String appName, in DbHandle dbHandleName,
  	  in String verifiedUri);

  /**
   * Get the document ETag values for the given file under the specified Uri.
   * The assumption is that the file system will update the modification timestamp
   * if the file has changed. This eliminates the need for computing an md5
   * hash on files that haven't changed. We can just retrieve that from the database.
   *
   * @param appName
   * @param dbHandleName
   * @param verifiedUri (e.g., https://opendatakit-tablesdemo.appspot.com)
   * @param tableId  (null if an application-level file)
   * @param modificationTimestamp timestamp of last file modification
   */
  String getFileSyncETag(in String appName, in DbHandle dbHandleName,
  	  in String verifiedUri, in String tableId, in long modificationTimestamp);

  /**
   * Get the document ETag values for the given manifest under the specified Uri.
   *
   * @param appName
   * @param dbHandleName
   * @param verifiedUri (e.g., https://opendatakit-tablesdemo.appspot.com)
   * @param tableId  (null if an application-level manifest)
   */
  String getManifestSyncETag(in String appName, in DbHandle dbHandleName,
  	  in String verifiedUri, in String tableId);

  /**
   * Update the document ETag values for the given file under the specified Uri.
   * The assumption is that the file system will update the modification timestamp
   * if the file has changed. This eliminates the need for computing an md5
   * hash on files that haven't changed. We can just retrieve that from the database.
   *
   * @param appName
   * @param dbHandleName
   * @param verifiedUri (e.g., https://opendatakit-tablesdemo.appspot.com)
   * @param tableId  (null if an application-level file)
   * @param modificationTimestamp timestamp of last file modification
   * @param eTag
   */
  void updateFileSyncETag(in String appName, in DbHandle dbHandleName,
  	  in String verifiedUri, in String tableId, in long modificationTimestamp,
  	  in String eTag);

  /**
   * Update the document ETag values for the given manifest under the specified Uri.
   *
   * @param appName
   * @param dbHandleName
   * @param verifiedUri (e.g., https://opendatakit-tablesdemo.appspot.com)
   * @param tableId  (null if an application-level manifest)
   * @param eTag
   */
  void updateManifestSyncETag(in String appName, in DbHandle dbHandleName,
  	  in String verifiedUri, in String tableId, in String eTag);

  /**
   * Retrieve partitions of data from an earlier call.
   *
   * @param chunkID The unique id of the data parition
   * @return The data partition, which contains a pointer to the next partition if it exists.
   */
  DbChunk getChunk(in ParcelUuid chunkID);
}
