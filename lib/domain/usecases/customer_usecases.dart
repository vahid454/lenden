import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/customer_entity.dart';
import '../repositories/customer_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Each use case encapsulates a single business operation.
// Presentation layer calls these; use cases call the repository.
// ─────────────────────────────────────────────────────────────────────────────

/// Watches a real-time stream of all customers for the signed-in user.
class WatchCustomersUseCase {
  final CustomerRepository _repository;
  const WatchCustomersUseCase(this._repository);

  Stream<Either<Failure, List<CustomerEntity>>> call(String userId) {
    return _repository.watchCustomers(userId);
  }
}

/// Adds a new customer record to Firestore.
class AddCustomerUseCase {
  final CustomerRepository _repository;
  const AddCustomerUseCase(this._repository);

  Future<Either<Failure, CustomerEntity>> call(CustomerEntity customer) {
    return _repository.addCustomer(customer);
  }
}

/// Updates an existing customer's details in Firestore.
class UpdateCustomerUseCase {
  final CustomerRepository _repository;
  const UpdateCustomerUseCase(this._repository);

  Future<Either<Failure, CustomerEntity>> call(CustomerEntity customer) {
    return _repository.updateCustomer(customer);
  }
}

/// Deletes a customer and cascades deletion of their transactions.
class DeleteCustomerUseCase {
  final CustomerRepository _repository;
  const DeleteCustomerUseCase(this._repository);

  Future<Either<Failure, void>> call(String customerId) {
    return _repository.deleteCustomer(customerId);
  }
}

/// Fetches a single customer by ID (used for detail view).
class GetCustomerUseCase {
  final CustomerRepository _repository;
  const GetCustomerUseCase(this._repository);

  Future<Either<Failure, CustomerEntity>> call(String customerId) {
    return _repository.getCustomer(customerId);
  }
}

/// Searches customers by name with a case-insensitive prefix match.
class SearchCustomersUseCase {
  final CustomerRepository _repository;
  const SearchCustomersUseCase(this._repository);

  Future<Either<Failure, List<CustomerEntity>>> call({
    required String userId,
    required String query,
  }) {
    return _repository.searchCustomers(userId: userId, query: query);
  }
}
