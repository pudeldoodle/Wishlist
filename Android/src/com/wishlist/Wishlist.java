/*
 * Copyright 2004 - Present Facebook, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.wishlist;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;

import org.apache.http.HttpResponse;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.entity.mime.HttpMultipartMode;
import org.apache.http.entity.mime.MultipartEntity;
import org.apache.http.entity.mime.content.ByteArrayBody;
import org.apache.http.impl.client.DefaultHttpClient;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.ProgressDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.graphics.BitmapFactory;
import android.graphics.drawable.BitmapDrawable;
import android.location.Criteria;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.provider.MediaStore;
import android.text.TextUtils;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.BaseAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.ImageView;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

import com.facebook.android.AsyncFacebookRunner;
import com.facebook.android.Facebook;
import com.facebook.android.FacebookError;
import com.facebook.android.R;
import com.facebook.android.Util;
import com.wishlist.Utility;
import com.wishlist.SessionEvents.AuthListener;
import com.wishlist.SessionEvents.LogoutListener;

public class Wishlist extends Activity {

    /* Your Facebook Application ID must be set before running this example
     * See http://www.facebook.com/developers/createapp.php
     */
	//TODO
    public static final String APP_ID = "{APP_ID}";
    
    //TODO
    private static final String HOST_SERVER_URL = "{SERVER_URL}";
    
    //TODO
    private static final String WISHLIST_OBJECTS_URL[] = {
    	HOST_SERVER_URL + "{BIRTHDAY_PHP_URL}",
    	HOST_SERVER_URL + "{HOLIDAY_PHP_URL}",
    	HOST_SERVER_URL + "{WEDDING_PHP_URL}"
    };
      
    private static final String HOST_PHOTO_UPLOAD_URI = "photo_upload.php";
    private static final String HOST_PRODUCT_URI = "product.php";

    private LoginButton mLoginButton;
    private TextView mText;
    private EditText mProduceName;
    private ImageView mUserPic;
    private Handler mHandler;
    private ImageView image;
    private byte[] imageBytes = null;
    private LocationManager mLocationManager;
    private JSONArray mPlacesJSONArray;
    private Button mAddtoTimeline;
    protected boolean uploadCancelled;
    
    private boolean mPlacesAvailable = false;
    private String mProductImageName, mProductImageURL, mProductName;
	ProgressDialog dialog;
	
	private Spinner mWishlistSpinner, mPlacesListSpinner;

	final int AUTHORIZE_ACTIVITY_RESULT_CODE = 0;
	final int PICK_EXISTING_PHOTO_RESULT_CODE = 1;

    /** Called when the activity is first created. */
    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        if (APP_ID == null) {
            Util.showAlert(this, "Warning", "Facebook Applicaton ID must be " +
                    "specified before running this example: see FbAPIs.java");
            return;
        }

        setContentView(R.layout.wishlist);
        mHandler = new Handler();
        
        mText = (TextView) Wishlist.this.findViewById(R.id.txt);
        mUserPic = (ImageView)Wishlist.this.findViewById(R.id.user_pic);
        mProduceName = (EditText)Wishlist.this.findViewById(R.id.product_name);
        
        mWishlistSpinner = (Spinner)Wishlist.this.findViewById(R.id.wishlist_spinner);
        mPlacesListSpinner = (Spinner)Wishlist.this.findViewById(R.id.location);
        
        image = (ImageView)Wishlist.this.findViewById(R.id.itemPhoto);
        
        image.setImageResource(R.drawable.camera);
        image.setOnClickListener(new OnClickListener() {
			@Override
			public void onClick(View v) {
				Intent intent = new Intent(Intent.ACTION_PICK, (MediaStore.Images.Media.EXTERNAL_CONTENT_URI));
                startActivityForResult(intent, PICK_EXISTING_PHOTO_RESULT_CODE);
			}
        });
             
        ArrayAdapter<CharSequence> adapter = ArrayAdapter.createFromResource(
                this, R.array.wishlist_array, android.R.layout.simple_spinner_item);
        adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        mWishlistSpinner.setAdapter(adapter);
        
        mPlacesListSpinner.setClickable(false);
        
        mAddtoTimeline = (Button)Wishlist.this.findViewById(R.id.timeline);
        mAddtoTimeline.setOnClickListener(new OnClickListener() {
			@Override
			public void onClick(View v) {
				if(!Utility.mFacebook.isSessionValid()) {
					showToast(getString(R.string.must_login));
					return;
				}
				mProductName = mProduceName.getText().toString();
				if(mProductName == null || TextUtils.isEmpty(mProductName)) {
					showToast(getString(R.string.enter_product_name));
					return;
				}
				if(imageBytes == null) {
					showToast(getString(R.string.take_product_photo));
					return;
				}
				/*
				 * Upload photo first and then publish to the timeline after successful photo upload.
				 */
				uploadPhoto();
			}
        });
        /*
         * Initalize Facebook Object, retrieve access token and layout the Login button
         */
        initFacebook();
    }
    
    private void initFacebook() {   
        //Create the Facebook Object using the app id.
       	Utility.mFacebook = new Facebook(APP_ID);
       	//Instantiate the asynrunner object for asynchronous api calls.
       	Utility.mAsyncRunner = new AsyncFacebookRunner(Utility.mFacebook);

       	mLoginButton = (LoginButton) findViewById(R.id.login);
        
       	//restore session if one exists
        SessionStore.restore(Utility.mFacebook, this);
        SessionEvents.addAuthListener(new FbAPIsAuthListener());
        SessionEvents.addLogoutListener(new FbAPIsLogoutListener());

        mLoginButton.init(this, AUTHORIZE_ACTIVITY_RESULT_CODE, Utility.mFacebook, new String[]{"publish_actions", "offline_access"});
        
       	if(Utility.mFacebook.isSessionValid()) {
       		requestUserData();
       	} else {
       		setPlacesSpinnerAdapter(R.array.login_for_places);
       	}
        
    }
    
    @Override
    protected void onResume() {
        super.onResume();
        if(Utility.mFacebook != null && !Utility.mFacebook.isSessionValid()) {
	    	mText.setText("You are logged out! ");
	    	mLoginButton.updateButton();
	        mUserPic.setImageBitmap(null);
    	}
    }

    @Override
    protected void onPause() {
        super.onPause();
    }
    
    public void uploadPhoto() {
    	uploadCancelled = false;
    	dialog = ProgressDialog.show(Wishlist.this, "", getString(R.string.uploading_photo), true, true, new DialogInterface.OnCancelListener() {
			@Override
			public void onCancel(DialogInterface dialog) {
				uploadCancelled = true;
			}
    	});
    	
    	/*
    	 * Upload photo to the server in a new thread
    	 */
    	new Thread() {
			public void run() {
				try {
		        	String postURL = HOST_SERVER_URL + HOST_PHOTO_UPLOAD_URI;
		        	
		            HttpClient httpClient = new DefaultHttpClient();
		            HttpPost postRequest = new HttpPost(postURL);
		            
		            ByteArrayBody bab = new ByteArrayBody(imageBytes, "file_name_ignored");
		            MultipartEntity reqEntity = new MultipartEntity(HttpMultipartMode.BROWSER_COMPATIBLE);
		            reqEntity.addPart("source", bab);
		            postRequest.setEntity(reqEntity);
		            
		            HttpResponse response = httpClient.execute(postRequest);
		            BufferedReader reader = new BufferedReader(new InputStreamReader(
		                    response.getEntity().getContent(), "UTF-8"));
		            String sResponse;
		            StringBuilder s = new StringBuilder();
		            while ((sResponse = reader.readLine()) != null) {
		                s = s.append(sResponse);
		            }
		            /*
		             * JSONObject is returned with image_name and image_url
		             */
		            JSONObject jsonResponse = new JSONObject(s.toString());
		            mProductImageName = jsonResponse.getString("image_name");
		            mProductImageURL = jsonResponse.getString("image_url");
		            dismissDialog();
		            if(mProductImageName == null) {
		        		showToast(getString(R.string.error_uploading_photo));
		    			return;
		        	}
		            /*
		             * photo upload finish, now publish to the timeline
		             */
		            if(!uploadCancelled) {
			            mHandler.post(new Runnable() {
			                public void run() {
			    	            addToTimeline();
			                }
			        	});
		            }
		        } catch (Exception e) {
		            Log.e(e.getClass().getName(), e.getMessage());
		        }
			}
    	}.start();
    }
    
    /*
     * Publish COG Story
     * 
     */
    public void addToTimeline() {
		dialog = ProgressDialog.show(Wishlist.this, "", getString(R.string.adding_to_timeline), true, true);
		/*
		 * Create Product URL
		 */
		String productURL = HOST_SERVER_URL + HOST_PRODUCT_URI;
		Bundle productParams = new Bundle();
		productParams.putString("name", mProductName);
		productParams.putString("image", mProductImageName);
		productURL = productURL + "?" + Util.encodeUrl(productParams);
		
		Bundle wishlistParams = new Bundle();
		
		if(mPlacesAvailable) {
			try {
				wishlistParams.putString("place", mPlacesJSONArray.getJSONObject(mPlacesListSpinner.getSelectedItemPosition()).getString("id"));
			} catch (JSONException e) {}
		}
		wishlistParams.putString("wishlist", WISHLIST_OBJECTS_URL[mWishlistSpinner.getSelectedItemPosition()]);
		wishlistParams.putString("product", productURL);
		wishlistParams.putString("image", mProductImageURL);
		//TODO
		//put the app's namespace and 'add_to' action here
		Utility.mAsyncRunner.request("me/{namespace}:{add_to_action}", wishlistParams, "POST", new addToTimelineListener(), null);
    }
    
	/*
	 * Callback for the permission OAuth Dialog
	 */
	public class addToTimelineListener extends BaseRequestListener {

	    public void onComplete(final String response, final Object state) {
	    	dismissDialog();
	    	try {
	    		JSONObject json = new JSONObject(response);
	    		showAlertDialog(getString(R.string.added_to_timeline, mProductName), json.toString(2));
	    	} catch(JSONException e) {
	    		showToast("Error: " + e.toString());
	    	}
	    }
	    
	    public void onFacebookError(FacebookError error) {
	    	dismissDialog();
	    	showAlertDialog(getString(R.string.error), error.getMessage());
	    }
	}

	/*
	 * Called on successful authorization
	 * and after user picked a photo from the media gallery
	 */
    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
    	switch(requestCode) {
    		/*
    		 * if this is the activity result from authorization flow, do a call back to authorizeCallback
    		 * Source Tag: login_tag
    		 */
	    	case AUTHORIZE_ACTIVITY_RESULT_CODE: {
	    		Utility.mFacebook.authorizeCallback(requestCode, resultCode, data);
	    		break;
	    	}
	    	/*
	    	 * if this is the result for a photo picker from the gallery, upload the image after scaling it.
	    	 * You can use the Utility.scaleImage() function for scaling
	    	 */
	    	case PICK_EXISTING_PHOTO_RESULT_CODE: { 
	    		if (resultCode == Activity.RESULT_OK) {
	    			Uri imageUri = data.getData();
	    			((BitmapDrawable)image.getDrawable()).getBitmap().recycle();
	    			System.gc();
					try {
						imageBytes = Utility.scaleImage(getApplicationContext(), imageUri);
		    			image.setImageBitmap(BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.length));
		    			image.invalidate();
					} catch (IOException e) {
						showToast(getString(R.string.error_getting_image));
					}
		        } else {
		        	showToast(getString(R.string.no_image_selected));
		        }
	    		break;
		    }
    	}
    }
    

    /*
     * The Callback for notifying the application when authorization
     *  succeeds or fails.
     */
    
    public class FbAPIsAuthListener implements AuthListener {

        public void onAuthSucceed() {
        	requestUserData();
        }

        public void onAuthFail(String error) {
            mText.setText("Login Failed: " + error);
        }
    }

    /*
     * The Callback for notifying the application when log out
     *  starts and finishes.
     */
    public class FbAPIsLogoutListener implements LogoutListener {
        public void onLogoutBegin() {
            mText.setText("Logging out...");
        }

        public void onLogoutFinish() {
            mText.setText("You have logged out! ");
            mUserPic.setImageBitmap(null);
            setPlacesSpinnerAdapter(R.array.login_for_places);
        }
    }
   
    
    /*
     * Request user name, and picture to show on the main screen.
     */
    public void requestUserData() {
    	mText.setText("Fetching user name, profile pic...");
    	Bundle params = new Bundle();
   		params.putString("fields", "name, picture");
		Utility.mAsyncRunner.request("me", params, new UserRequestListener());
		
		/*
		 * fetch current location and
		 * nearby places
		 */
		setPlacesSpinnerAdapter(R.array.init_location_array);
		fetchCurrentLocation();
    }
    
    /*
     * Callback for fetching current user's name, picture, uid.
     */
    public class UserRequestListener extends BaseRequestListener {

        public void onComplete(final String response, final Object state) {
        	JSONObject jsonObject;
			try {
				jsonObject = new JSONObject(response);
				
	        	final String picURL = jsonObject.getString("picture");
	        	final String name = jsonObject.getString("name");
	        	Utility.userUID = jsonObject.getString("id");
	        	
	        	mHandler.post(new Runnable() {
	                public void run() {
	                	mText.setText("Welcome " + name + "!");
	    	        	mUserPic.setImageBitmap(Utility.getBitmap(picURL));
	                }
	            });
	        	
			} catch (JSONException e) {
				e.printStackTrace();
			}
        }

    }
    
    /*
     * Fetch user's current location in a new thread
     */
    public void fetchCurrentLocation(){
    	new Thread() {
			public void run() {
	        	Looper.prepare();
	        	mLocationManager = (LocationManager) getSystemService(Context.LOCATION_SERVICE);
	        	MyLocationListener locationListener = new MyLocationListener(); 
	        	Criteria criteria = new Criteria();
	        	criteria.setAccuracy(Criteria.ACCURACY_COARSE);
	        	String provider = mLocationManager.getBestProvider(criteria, true);
	        	if (provider != null && mLocationManager.isProviderEnabled(provider)) {
	        		mLocationManager.requestLocationUpdates(provider, 1, 0, locationListener, Looper.getMainLooper());
	        	} else {
	        		showToast("Please turn on handset's GPS");
	        	}
	        	Looper.loop();
			}
    	}.start();
    }
    
    /*
     * Callback for location, if location successfully fetched, fetch nearby places
     */
    class MyLocationListener implements LocationListener {
    	
    	@Override
    	public void onLocationChanged(Location loc) {
    		if (loc != null) {
    			mLocationManager.removeUpdates(this);
    			setPlacesSpinnerAdapter(R.array.fetch_places_array);
    			fetchPlaces(loc.getLatitude(), loc.getLongitude());
    		}
    	}

		@Override
		public void onProviderDisabled(String provider) {			
		}

		@Override
		public void onProviderEnabled(String provider) {
		}

		@Override
		public void onStatusChanged(String provider, int status, Bundle extras) {
		}
    }
    
    /*
     * Fetch nearby places by calling graph.facebook.com/search
     */
    private void fetchPlaces(double lat, double lon) {
    	if (!isFinishing()) {
			Bundle params = new Bundle();
			params.putString("type", "place");
			params.putString("center", String.valueOf(lat) + "," + String.valueOf(lon));
			params.putString("distance", "1000");
			Utility.mAsyncRunner.request("search", params, new placesRequestListener());
    	}
    }
    
    /*
     * Callback for nearyby places via graph.facebook.com/search
     */
	public class placesRequestListener extends BaseRequestListener {

        public void onComplete(final String response, final Object state) {
            try {
    			mPlacesJSONArray = new JSONObject(response).getJSONArray("data");
    		} catch (JSONException e) {
    			showToast(getString(R.string.no_places_fetched));
    		}
    		/*
    		 * Update the Places Spinner with nearby places name
    		 */
    		mHandler.post(new Runnable() {
                public void run() {
                	mPlacesListSpinner.setAdapter(new PlacesListAdapter(Wishlist.this));
                	mPlacesListSpinner.setClickable(true);
                    mPlacesAvailable = true;
                }
    		});
            
        }
        
	    public void onFacebookError(FacebookError error) {
	    	dialog.dismiss();
	    	showToast("Fetch Places Error: " + error.getMessage());
	    }
    }
    
	/*
	 * Show a toast in the main thread.
	 */
    public void showToast(final String msg) {
    	mHandler.post(new Runnable() {
            public void run() {
	            Toast toast = Toast.makeText(Wishlist.this, msg, Toast.LENGTH_LONG);
				toast.show();
            }
    	});
    }
    
    /*
     * Dismiss dialog in the main thread.
     */
    public void dismissDialog() {
    	mHandler.post(new Runnable() {
            public void run() {
	            dialog.dismiss();
            }
    	});
    }
    
    /*
     * Show Alert Dialog
     */
    public void showAlertDialog(final String title, final String message) {
    	mHandler.post(new Runnable() {
            public void run() {
		    	new AlertDialog.Builder(Wishlist.this)
		    	.setTitle(title)
		    	.setMessage(message)
		    	.setPositiveButton(getString(R.string.ok), new DialogInterface.OnClickListener() {
		    		public void onClick(DialogInterface dialog, int which) { 
		    			return;  
		    		} 
		    	})
		        .show();
            }
    	});
    }
    
    /*
     * Set Places spinner adapter
     */
    public void setPlacesSpinnerAdapter(int spinner_array) {
		ArrayAdapter<CharSequence> location_adapter = ArrayAdapter.createFromResource(
	            this, spinner_array, android.R.layout.simple_spinner_item);
	    location_adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
	    mPlacesListSpinner.setAdapter(location_adapter);
	    mPlacesListSpinner.invalidate();
    }
    
    /**
     * Definition of the list adapter
     */
	public class PlacesListAdapter extends BaseAdapter {
		private LayoutInflater mInflater;
		
		public PlacesListAdapter(Context context) {
			mInflater = LayoutInflater.from(context);
		}
		
		@Override
		public int getCount() {
			return mPlacesJSONArray.length();
		}
		
		@Override
		public Object getItem(int position) {
			return null;
		}

		@Override
		public long getItemId(int position) {
			return 0;
		}
		
		@Override
		public View getView(int position, View convertView, ViewGroup parent) {
			JSONObject jsonObject = null;
			try {
				jsonObject = mPlacesJSONArray.getJSONObject(position);
			} catch (JSONException e1) {
				e1.printStackTrace();
			}
			View hView = convertView;
			if(convertView == null) {
				hView = mInflater.inflate(R.layout.place_item, null);
				ViewHolder holder = new ViewHolder();
				holder.name = (TextView) hView.findViewById(R.id.place_name);
				hView.setTag(holder);
			}

			ViewHolder holder = (ViewHolder) hView.getTag();
			try {
				holder.name.setText(jsonObject.getString("name"));
			} catch (JSONException e) {
				holder.name.setText("");
			}

			return hView;
		}	
		
	}
	
	class ViewHolder {
		TextView name;
	}

}
