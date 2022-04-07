import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:webxene_core/auth_manager.dart';
import 'package:webxene_core/instance_manager.dart';
import 'package:webxene_core/widgets/spinning_icon.dart';

class LoginScreenController extends GetxController {
	final pending = false.obs;
	void busy() { pending.value = true; }
	void finished() { pending.value = false; }

	final authState = AuthState.init.obs;
	final errorMsg = "".obs;
	void mirrorState(AuthState original) {
		authState.value = original;
	}
	void showError(String message) {
		errorMsg.value = message;
		authState.value = AuthState.error;
	}
}

class LoginScreen extends StatefulWidget {
	const LoginScreen({Key? key}) : super(key: key);

	@override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
	TextEditingController loginName = TextEditingController();
	TextEditingController loginPassword = TextEditingController();

	late AnimationController _animationController;      // Animations for hero icon
	final LoginScreenController controller = LoginScreenController();

	@override void dispose() {
		loginName.dispose(); loginPassword.dispose();
		_animationController.dispose();
		super.dispose();
	}

	@override void initState() {
		super.initState();

		// TODO: Initialize with testing server HTTP only for now!
		InstanceManager().setupInstance("netxene.cirii.org", { 'instance': {'DEBUG_HTTP': true }});

		controller.mirrorState(AuthManager().state);
		_animationController = AnimationController(
			vsync: this,
			duration: const Duration(seconds: 4),
		);
	}

	@override Widget build(BuildContext context) {
		const txtHero = Text("NetXene", style: TextStyle(fontSize: 18));
		final imgHero = SpinningIcon(
			controller: _animationController,
			iconData: Icons.stream_outlined,
			iconSize: 64,
		);
		_animationController.repeat();

		List<Widget> stateWidgets = [];
		print("Building context for authState: " + controller.authState.value.toString());
		switch (controller.authState.value) {
			case AuthState.init:
				stateWidgets = _buildLogin(context); break;
			case AuthState.keyPrompt:
				stateWidgets = _buildKeyPrompt(context); break;
			default:
				print("Default fallthrough!");
				break;
		}

		return Material(
			child: Stack(
				alignment: Alignment.topCenter,
				children: [
					const Positioned.fill(
						child: Image(
							image: AssetImage('assets/bg-login.jpg'),
							fit : BoxFit.cover,
						),
					),
					SingleChildScrollView(
						child: Padding(
							padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
							child: Column(
								children: [ imgHero, txtHero, ...stateWidgets ],
							),
						),
					),
				],
			),
		);
	}

	List<Widget> _buildLogin(BuildContext context) {
		final txtLoginName = TextFormField(
			controller: loginName,
			decoration: const InputDecoration(
				icon: Icon(Icons.contact_mail),
				hintText: "Enter your email address",
				labelText: "Login email",
			),
			autovalidateMode: AutovalidateMode.onUserInteraction,
			validator: (String? value) {
				return (value != null && value.contains('@')) ? null : "Please enter an email address.";
			},
			onChanged: (value) {
				//setState(() {});
			},
		);

		final txtLoginPassword = TextFormField(
			controller: loginPassword,
			obscureText: true,
			decoration: const InputDecoration(
				icon: Icon(Icons.password),
				hintText: "Enter your password",
				labelText: 'Password',
			),
			autovalidateMode: AutovalidateMode.onUserInteraction,
			validator: (String? value) {
				return (value != null && value != "") ? null : "Please enter your password.";
			},
			onChanged: (value) {
				//setState(() {});
			},
		);

		final btnRunLogin = TextButton.icon(
			icon: Icon(controller.pending.value ? Icons.hourglass_top : Icons.login),
			label: Container(
				child: Text(
					controller.pending.value ? "Loading..." : "Sign in",
					style: TextStyle(fontSize: 16),
				),
				width: 100,
				height: 30,
				alignment: Alignment.center,
			),
			style: TextButton.styleFrom(
				primary: Colors.white,
				backgroundColor: Colors.blueAccent,
				shape: RoundedRectangleBorder(
					borderRadius: BorderRadius.circular(8),
				),
			),
			onPressed: () {
				if (controller.pending.value) {
					return;
				}
				InstanceManager().setupInstance("netxene.cirii.org", { 'instance': {'DEBUG_HTTP': true }});

				AuthManager().runSingleStageLogin(loginName.text, loginPassword.text).then((_) {
					if (AuthManager().state == AuthState.complete) {
						Navigator.pushNamed(context, '/home');
					}
				});
			},
		);

		final topWarning = Container(
			decoration: BoxDecoration(
				border: Border.all(width: 2),
				color: Colors.orangeAccent[100],
			),
			margin: const EdgeInsets.symmetric(vertical: 5),
			padding: const EdgeInsets.all(5),
			child: Row(
				mainAxisAlignment: MainAxisAlignment.center,
				children: const [
					Icon(Icons.warning),
					Padding(padding: EdgeInsets.symmetric(horizontal: 3)),
					Text("Temporary UI"),
				],
			),
		);

		return [ topWarning, txtLoginName, txtLoginPassword, const Padding(padding: EdgeInsets.all(10)), btnRunLogin ];
	}

	List<Widget> _buildKeyPrompt(BuildContext context) {
		final rowKeyDetails = Row(
			children: [
				const Padding(padding: const EdgeInsets.all(10)),
				Column(children: const [
					Icon(Icons.lock, size: 36),
					Text("Key #??p??\n<timestamp>"),
				]),
				const Padding(padding: EdgeInsets.all(20)),
				Column(children: const [
					Text("[[ Username ]]"),
					Text("[[ Recognition ]]"),
				]),
				const Padding(padding: const EdgeInsets.all(10)),
			],
		);

		final btnEnterKey = TextButton.icon(
			icon: const Icon(Icons.vpn_key_sharp),
			label: Container(
				child: const Text("Unlock key for login", style: TextStyle(fontSize: 16)),
				width: 200,
				height: 30,
				alignment: Alignment.center,
			),
			style: TextButton.styleFrom(
				primary: Colors.white,
				backgroundColor: Colors.blueAccent,
				shape: RoundedRectangleBorder(
					borderRadius: BorderRadius.circular(8),
				),
			),
			onPressed: () {
				if (controller.pending.value) {
					return;
				}
			},
		);

		return [ rowKeyDetails, btnEnterKey ];
	}

}

