// Singleton class to store authentication details for current user.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tuple/tuple.dart';
import 'package:webxene_fpt/users/login_screen.dart';
import 'users/user.dart';
import "instance_manager.dart";
import 'users/user_recognition.dart';

// TODO: Move these to separate classes
class NotFoundException implements Exception {
}
enum UserKeypairType {
	public,
	temp,
	invalid
}
class UserKeypair {                 // NB: These represent only the PUBLIC part of keypairs (encryption+signing) as stored in API backend.
	int id = 0;                     // Keypair ID, as reported by server - not the same as user ID!
	int timestamp = 0;              // UNIX timestamp of key creation.
	UserKeypairType type = UserKeypairType.invalid;     // Type of this keypair as reported by server. See backend Keypair model for more information.

	UserKeypair.fromJson(Map<String, dynamic> json, { bool enforceSentinel = false, bool enforceValid = false }) {
		id = json['id'];
		timestamp = json['timestamp'];
		type = UserKeypairType.values.byName(json['type']);     // (throws error if this enum type is not found!)

		if (enforceSentinel) {      // Enforce sentinel value - timestamp of request must be within one hour.
			final int sentinel = json['sentinel'] ?? 0;
			final int sentinelDiff = (sentinel - (DateTime.now().millisecondsSinceEpoch / 1000).round()).abs();
			if (sentinelDiff > (60*60)) {
				throw Exception("Invalid sentinel value for keypair: exceeds $sentinelDiff seconds!");
			}
		}

		if (enforceValid) {         // Enforce validity flag - require a 'valid' flag on this keypair meaning it is the most recent valid keypair.
			if (!(json['valid'] ?? false)) {
				throw Exception("Keypair validity flag is not set for keypair $id, aborting!");
			}
		}
	}
}


enum AuthState {
	init,               // Startup - request for login name or identifier.
	password,           // Login request for password only.
	passwordTOTP,       // Login request for password + 2FA.
	forgot,             // Forgot password request.
	keyPrompt,          // Prompt for key entry
	complete,           // Logged in and authenticated.
	error,              // Error message display.
}
class AuthManager {
	static AuthManager? _instance;
	factory AuthManager() => _instance ??= new AuthManager._singleton();
	AuthManager._singleton();       // Empty singleton constructor

	UserRecognition? _recognition;          // Recognition object used as part of login to describe partial user details.
	AuthState state = AuthState.init;       // State the Auth Manager is in, used to render UI or check logged-in status.
	User loggedInUser = User();             // Last user we logged in as successfully, or empty user.

	String _apiToken = '';                  // API token for this login session.

	// Temporary login sequence that bypasses AuthState to do everything in one step.
	// TODO: Fix this to use separate pages, as required by 2FA/TOTP and other uses.
	Future<void> runSingleStageLogin(String username, String password) async {
		try {
			// Lookup recognition for this username to get uid, etc.
			await lookupLoginDetails(username);
			if (_recognition == null) {
				throw Exception("Failed to recognize user!");
			} else if (_recognition!.passwordEmpty) {
				throw UnimplementedError("Can't login to uninitialized user accounts yet!");
			} else if (_recognition!.totpEnabled) {
				throw UnimplementedError("Can't login to 2FA-enabled user accounts yet!");
			}

			// Exchange password for API token and user details.
			final loginResults = await attemptLoginTokenExchange(_recognition!.id, password);
			loggedInUser = loginResults.item1;
			_apiToken = loginResults.item2;
			print("Login token exchange complete: " + loggedInUser.name);

			// Get keypair for logged in user to obtain instance details.
			final keypairRemoteFetch = await getLoggedInKeypair(getInstanceInitializer: true);
			final keypairRemote = keypairRemoteFetch.item1;
			final instanceConfig = keypairRemoteFetch.item2;
			InstanceManager().setupInstance(null, instanceConfig?['instance']);
			print("Remote keypair identified: id ${keypairRemote.id} is valid.");
			final keypairRecovered = await attemptKeyRecovery(keypairRemote);

			// Attempt to unlock keypair with securecode to unlock UserCrypto operations.
			// TODO: Implement proper securecode lookup for non-defaults!
			await loggedInUser.DecryptSecurekey(InstanceManager().defaultSecurecode, keypairRecovered['pbkdf2_iter'], keypairRecovered['pbkdf2_salt'], keypairRecovered['aesEncrypted'], keypairRecovered['hmac']);
			print("Unlocked remote keypair successfully with securecode. Crypto operations now live for user ${loggedInUser.id}.");
			state = AuthState.complete;
		} on NotFoundException {
			rethrow;
		} catch (ex) {
			rethrow;
		}
	}

	// Lookup a username or contact to obtain details required for login, including 2FA status, recognition, etc.
	Future<void> lookupLoginDetails(String username) async {
		final apiResolveUser = await InstanceManager().apiRequest('users', { 'lookup': username });
		if (!apiResolveUser.success(APIResponseJSON.map)) {
			throw apiResolveUser.response.statusCode == 404 ?
					NotFoundException() :
					Exception("${apiResolveUser.response.statusCode}: ${apiResolveUser.response.reasonPhrase ?? 'Unknown error'}");
		}
		_recognition = UserRecognition.fromJson(apiResolveUser.result);
	}

	// Attempt login user and token exchange for password.
	Future<Tuple2<User, String>> attemptLoginTokenExchange(int uid, String password) async {
		final apiLogin = await InstanceManager().apiRequest("users/$uid/login", {
			'password': password,
			'totp_auth': null,
		}, 'POST');
		if (!apiLogin.success(APIResponseJSON.map)) {
			throw apiLogin.response.statusCode == 404 ?
				NotFoundException() :
				Exception("${apiLogin.response.statusCode}: ${apiLogin.response.reasonPhrase ?? 'Unknown error'}");
		}
		// Make sure api_token does not remain in the user JSON.
		final userApiToken = apiLogin.result['api_token'];
		apiLogin.result['api_token'] = '';
		return Tuple2(User.fromJson(apiLogin.result), userApiToken);
	}

	// Get our current keypair for the logged in user, along with login instance configuration, etc. if required.
	Future<Tuple2<UserKeypair, Map<String, dynamic>?>> getLoggedInKeypair({ bool getInstanceInitializer = false }) async {
		final apiKeypair = await InstanceManager().apiRequest('keypairs', {
			'fetch_only': getInstanceInitializer ? '0' : '1',
		});
		if (!apiKeypair.success(APIResponseJSON.map)) {
			throw Exception("${apiKeypair.response.statusCode}: ${apiKeypair.response.reasonPhrase ?? 'Unknown error'}");
		}
		final keypair = UserKeypair.fromJson(apiKeypair.result, enforceSentinel: true, enforceValid: true);
		if (!getInstanceInitializer) {
			return Tuple2(keypair, null);
		}
		// Separate instance configuration from keypair details and return them separately.
		final instanceConfig = {
			'actions': apiKeypair.result['actions'],
			'schemas': apiKeypair.result['schemas'],
			'instance': apiKeypair.result['instance'],
		};
		return Tuple2(keypair, instanceConfig);
	}

	// Attempt to recover keypair from server via recovery, returning JSON map of encrypted key (unlocked by passphrase).
	Future<Map<String, dynamic>> attemptKeyRecovery(UserKeypair keypair) async {
		final apiRecoveryCode = await InstanceManager().apiRequest("keypairs/${keypair.id}/recover", null, 'POST');
		if (!apiRecoveryCode.success(APIResponseJSON.map)) {
			throw Exception("Failed to generate recovery code for user keypair ${keypair.id} -- "
				"${apiRecoveryCode.response.statusCode}: ${apiRecoveryCode.response.reasonPhrase ?? 'Unknown error'}");
		}
		print("Warning: Stubbing key recovery until webcrypto SHA-384 code fix...");
		// TODO: Fix webcrypto problem with backup hash generation! Until now we use a fixed key.
		const fixedDebugKey = '{"aesEncrypted":"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","hmac":"ffHRf4l2M4EsXwY9p4/d+P6KoVQ=","pbkdf2_salt":"aALNGUxPxAN+byvclubTVg==","pbkdf2_iter":"HVMAAA=="}';
		return jsonDecode(fixedDebugKey);
	}

	// Attempt to do a full login with lookup, keypair and api token retrieval.
	/* TODO: Restore this once we have AuthState working!
		Future<bool> attemptUsernameLogin(LoginScreenController parent, String username, String password) async {
			if (state != AuthState.init) {
				throw Exception("Invalid authmanager state for login lookup!");
			}
			parent.busy();

			try {
				final usernameRequest = await InstanceManager().apiRequest('users', { 'lookup': username });
				if (!usernameRequest.success(APIResponseJSON.map)) {
					if (usernameRequest.response.statusCode == 404) {
						parent.showError("Login username was not found.");
					} else {
						parent.showError(usernameRequest.response.statusCode.toString() + ": " + (usernameRequest.response.reasonPhrase ?? "Unknown error"));
					}
					parent.finished();
					return false;
				}
				_loginTOTP = usernameRequest.result['totp_enabled'] == 1;
				_loginRecognition = usernameRequest.result['recognition'];
				state = AuthState.keyPrompt;
				final apiKeypair = await InstanceManager().apiRequest('keypairs');
				print(apiKeypair.result);
				parent.mirrorState(state);
				parent.finished();
				return true;
			} catch (ex) {
				parent.showError("Error looking up this login username!");
				parent.finished();
				rethrow;
			}
		}
		 */

}