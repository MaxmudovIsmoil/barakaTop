<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\DashboardController;
use App\Http\Controllers\ProductController;
use App\Http\Controllers\OrderController;
use App\Http\Controllers\SubCategoryController;
use App\Http\Controllers\OrderHistoryController;
use App\Http\Controllers\PartnerController;
use App\Http\Controllers\UsersController;
use App\Http\Controllers\StatisticController;
use App\Http\Controllers\FirebaseController;


/*
|--------------------------------------------------------------------------
| Web Routes
|--------------------------------------------------------------------------
|
| Here is where you can register web routes for your application. These
| routes are loaded by the RouteServiceProvider within a group which
| contains the "web" middleware group. Now create something great!
|
*/

Route::get('/', [App\Http\Controllers\HomeController::class, 'index'])->name('home');

Auth::routes();


Route::middleware(['auth', 'isAdmin'])->group(function () {


    Route::get('/firebase', [FirebaseController::class, 'index'])->name('firebase.index');
    Route::post('/save-push-notification-token', [FirebaseController::class, 'savePushNotificationToken'])->name('save-push-notification-token');
    Route::post('/send-push-notification-test', [FirebaseController::class, 'sendPushNotificationTest'])->name('send.push-notification-test');


    Route::get('dashboard', [DashboardController::class, 'index'])->name('dashboard');

    /******************** Users ***********************/
    Route::group(['prefix' => '/'], function() {
        Route::resource('/statistic', StatisticController::class)->except(['create', 'edit', 'show']);
        Route::post('/statistic/get-statistic/', [StatisticController::class, 'getStatistic'])->name('statistic.getStatistic');
        Route::get('/statistic/get-data-diagram/', [StatisticController::class, 'get_order_and_client_data_for_diagram'])->name('statistic.get_order_and_client_data_for_diagram');
    });
    /******************** Users ***********************/



    /******************** Users ***********************/
    Route::group(['prefix' => '/'], function() {
        Route::resource('/user', UsersController::class)->except(['create', 'edit', 'show']);
        Route::get('/user/one-user/{id}', [UsersController::class, 'oneUser'])->name('user.oneUser');
        Route::get('/user-profile-show/', [UsersController::class, 'user_profile_show'])->name('user.user_profile_show');
        Route::put('/user/user-profile-update/{id}', [UsersController::class, 'user_profile_update'])->name('user.user_profile_update');
    });
    /******************** Users ***********************/


    /******************** Products ***********************/
    Route::group(['prefix' => '/'], function() {
        Route::resource('/product', ProductController::class);
        Route::get('/one-product/{id}', [ProductController::class, 'one_product'])->name('product.one_product');
    });
    /******************** ./Products *********************/


    /******************** Orders ***********************/
    Route::group(['prefix' => '/'], function() {
        Route::resource('/order', OrderController::class)->except(['create', 'show']);
        Route::get('/order/get-orders/{id}', [OrderController::class, 'getOrders'])->name('order.getOrders');
        Route::get('/one-order/{id}', [OrderController::class, 'oneOrder'])->name('order.oneOrder');
        Route::get('/order/get-product/{partner_id}/{parent_id}', [OrderController::class, 'getProduct']);
        Route::post('/order/get-product-search/', [OrderController::class, 'getProductSearch']);

        Route::post('/order/status-update/{order_id}', [OrderController::class,'status_update'])->name('order.status_update');
        Route::post('/order/get-client-name', [OrderController::class,'get_client_name']);
    });
    /******************** ./Orders *********************/


    /******************** Orders history ***********************/
    Route::group(['prefix' => '/'], function() {
        Route::resource('/order-history', OrderHistoryController::class)->except(['create', 'show', 'edit', 'update', 'store']);
        Route::get('/order-history/get-order-history/', [OrderHistoryController::class, 'getOrderHistory'])->name('order-history.getOrderHistory');
    });
    /******************** ./Orders history *********************/


    /******************** Partners ***********************/
    Route::group(['prefix' => '/'], function() {
        Route::resource('/partner', PartnerController::class);
        Route::post('/partner/partner-open-close', [PartnerController::class, 'open_close'])->name('partner.open_close');
    });
    /******************** ./Partners ***********************/


    /******************** Sub Category ***********************/
    Route::group(['prefix' => '/'], function() {
        Route::resource('/sub-category', SubCategoryController::class)->except(['create', 'edit']);
        Route::get('/sub-category/get-sub-category/{id}', [SubCategoryController::class, 'get_sub_category']);
    });
    /******************** ./Sub Category ***********************/

});
