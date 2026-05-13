import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import '../models/student_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Real-time auth state stream
  Stream<User?> get userStream => _auth.authStateChanges();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Profile Management
  Future<void> updateStudentProfile(Student student) async {
    await _firestore.collection('students').doc(student.uid).set(student.toMap(), SetOptions(merge: true));
  }

  Future<Student?> getStudentProfile(String uid) async {
    final doc = await _firestore.collection('students').doc(uid).get();
    if (doc.exists) {
      return Student.fromMap(doc.data()!);
    }
    return null;
  }

  Stream<Student?> getStudentStream(String uid) {
    return _firestore.collection('students').doc(uid).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return Student.fromMap(doc.data()!);
      }
      return null;
    });
  }

  Future<String> uploadProfileImage(String uid, Uint8List fileBytes) async {
    final ref = _storage.ref().child('profiles').child('$uid.jpg');
    final uploadTask = await ref.putData(fileBytes, SettableMetadata(contentType: 'image/jpeg'));
    return await uploadTask.ref.getDownloadURL();
  }

  Future<Uint8List?> getProfileImageBytes(String uid) async {
    try {
      final ref = _storage.ref().child('profiles').child('$uid.jpg');
      return await ref.getData(1024 * 1024 * 5); // Max 5MB
    } catch (e) {
      return null;
    }
  }
  Future<User?> signUp(String email, String password) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      print("FirebaseAuthException in signUp: ${e.code} - ${e.message}");
      rethrow;
    } catch (e) {
      print("Unknown error in signUp: $e");
      rethrow;
    }
  }

  // Sign in with email & password
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      print("FirebaseAuthException in signIn: ${e.code} - ${e.message}");
      rethrow;
    } catch (e) {
      print("Unknown error in signIn: $e");
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
