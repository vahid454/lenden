import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/customer_entity.dart';

/// Abstract contract for all customer data operations.
/// The domain and presentation layers only depend on this interface,
/// never on Firebase or any concrete data source.
abstract class CustomerRepository {
  /// Real-time stream of all customers for [userId], ordered by name.
  /// Emits a new list whenever Firestore data changes.
  Stream<Either<Failure, List<CustomerEntity>>> watchCustomers(String userId);

  /// Adds a new customer to Firestore.
  /// Returns the saved [CustomerEntity] with the Firestore-generated ID.
  Future<Either<Failure, CustomerEntity>> addCustomer(CustomerEntity customer);

  /// Updates an existing customer document in Firestore.
  Future<Either<Failure, CustomerEntity>> updateCustomer(
      CustomerEntity customer);

  /// Deletes a customer and all their associated transactions.
  Future<Either<Failure, void>> deleteCustomer(String customerId);

  /// Fetches a single customer by [customerId].
  Future<Either<Failure, CustomerEntity>> getCustomer(String customerId);

  /// Searches customers by name (case-insensitive prefix match).
  Future<Either<Failure, List<CustomerEntity>>> searchCustomers({
    required String userId,
    required String query,
  });
}
