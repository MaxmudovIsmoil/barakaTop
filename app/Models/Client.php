<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Client extends Model
{
    use HasFactory;

    protected $table = 'client';

    public $timestamps = false;

    protected $fillable = [
        'name',
        'phone',
        'group_id',
        'token',
        'blocked',
        'pincode',
        'counter1',
        'counter2',
        'counter2_date',
        'counter3',
        'code',
        'counter3_date',
        'deposit',
        'password',
    ];

}
