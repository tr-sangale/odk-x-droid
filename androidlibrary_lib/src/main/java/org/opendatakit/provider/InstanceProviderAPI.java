/*
 * Copyright (C) 2007 The Android Open Source Project
 * Copyright (C) 2011-2013 University of Washington
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package org.opendatakit.provider;

import android.net.Uri;

/**
 * Instance provider returns rows from the underlying database table.
 * <p>
 * Used in InstanceProvider, InstanceUploaderTask
 */
@SuppressWarnings("unused")
public final class InstanceProviderAPI {
  /**
   * Used in InstanceProvider
   */
  @SuppressWarnings("WeakerAccess")
  public static final String AUTHORITY = "org.opendatakit.provider.instances";
  /**
   * Used in InstanceUploaderTask
   */
  public static final Uri CONTENT_URI = Uri.parse("content://" + AUTHORITY + "/");

  /**
   * This class cannot be instantiated
   */
  private InstanceProviderAPI() {
  }
}
